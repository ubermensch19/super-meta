import Foundation
import SwiftUI
import RealtimeVoice
import AIProviders
import GlassesKit

/// Drives a live realtime voice session: connects the OpenAI Realtime client,
/// pumps mic audio up and model audio down through the audio engine, surfaces
/// transcripts, and optionally injects glasses frames for visual context.
@MainActor
final class RealtimeSession: ObservableObject {
    enum Status: Equatable { case idle, connecting, live, error(String) }

    @Published var status: Status = .idle
    @Published var transcript = ""
    @Published var userLine = ""

    /// Resolves a model function call to its JSON result (see `HermesService.handleToolCall`).
    var toolHandler: ((_ name: String, _ argumentsJSON: String) async -> String)?

    private var client: (any RealtimeClient)?
    private let audio = RealtimeAudioEngine()
    private var eventTask: Task<Void, Never>?
    private var frameTask: Task<Void, Never>?

    private var providers: ProviderManager?
    private var glasses: GlassesService?

    /// The realtime API rejects response.create while a response is streaming,
    /// so tool outputs and announcements queue until the current one finishes.
    private var responseInFlight = false
    private var pendingResponseCreate = false
    private var announcementQueue: [String] = []

    init() {}

    /// Starts a session. `injectFrames` periodically sends a glasses frame as visual context.
    func start(
        instructions: String,
        voice: String = "alloy",
        providers: ProviderManager,
        glasses: GlassesService,
        injectFrames: Bool = false,
        tools: [RealtimeTool] = []
    ) {
        self.providers = providers
        self.glasses = glasses
        let vendor = providers.realtimeVendor
        let key = providers.realtimeAPIKey()
        guard !key.isEmpty else {
            status = .error("Add your \(vendor.displayName) API key in Settings for realtime voice.")
            return
        }
        status = .connecting
        transcript = ""
        userLine = ""
        responseInFlight = false
        pendingResponseCreate = false
        announcementQueue = []

        // The wake-word listener and a live session both want the mic/HFP route;
        // release the listener while we're connected, revive it on stop().
        WakeWordListener.shared.pause()

        // Gemini Live is the default; OpenAI Realtime stays available. Gemini needs
        // 16 kHz mic input, OpenAI 24 kHz.
        let config = RealtimeConfig(model: providers.realtimeModel, voice: voice, instructions: instructions, audio: true, tools: tools)
        let client: any RealtimeClient
        let captureRate: Double
        if vendor == .gemini {
            client = GeminiLiveClient(apiKey: key, config: config)
            captureRate = 16_000
        } else {
            client = OpenAIRealtimeClient(apiKey: key, config: config)
            captureRate = 24_000
        }
        self.client = client

        eventTask = Task { [weak self] in
            guard let self else { return }
            for await event in client.events {
                await self.handle(event)
            }
        }

        do {
            try audio.start(captureSampleRate: captureRate) { [weak client] chunk in client?.appendAudio(chunk) }
            client.connect()
            if injectFrames { startFrameInjection() }
        } catch {
            status = .error("Audio error: \(error.localizedDescription)")
        }
    }

    func stop() {
        frameTask?.cancel(); frameTask = nil
        eventTask?.cancel(); eventTask = nil
        audio.stop()
        client?.disconnect()
        client = nil
        status = .idle
        WakeWordListener.shared.resume()
    }

    /// Speaks a line proactively (e.g. a late hermes reply), waiting out any
    /// response that is currently streaming.
    func announce(_ text: String) {
        guard status == .live, client != nil else { return }
        if responseInFlight {
            announcementQueue.append(text)
        } else {
            client?.sendText(text)
        }
    }

    private func handle(_ event: RealtimeEvent) {
        switch event {
        case .sessionCreated, .sessionUpdated:
            status = .live
        case let .assistantAudioDelta(data):
            audio.enqueue(pcm16: data)
        case let .assistantTextDelta(delta):
            transcript += delta
        case let .userTranscript(text):
            userLine = text
        case .responseCreated:
            responseInFlight = true
        case .responseDone:
            transcript += "\n"
            responseInFlight = false
            drainQueuedWork()
        case let .functionCall(name, callID, argumentsJSON):
            runTool(name: name, callID: callID, argumentsJSON: argumentsJSON)
        case let .error(message):
            status = .error(message)
        case .other:
            break
        }
    }

    private func runTool(name: String, callID: String, argumentsJSON: String) {
        Task { @MainActor [weak self] in
            let output = await self?.toolHandler?(name, argumentsJSON)
                ?? #"{"error":"No agent is configured for tools"}"#
            guard let self, let client = self.client else { return }
            client.sendFunctionOutput(callID: callID, output: output)
            if self.responseInFlight {
                self.pendingResponseCreate = true
            } else {
                client.createResponse()
            }
        }
    }

    private func drainQueuedWork() {
        guard let client else { return }
        if pendingResponseCreate {
            pendingResponseCreate = false
            client.createResponse()
        } else if !announcementQueue.isEmpty {
            client.sendText(announcementQueue.removeFirst())
        }
    }

    private func startFrameInjection() {
        frameTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                guard let self, self.status == .live, let glasses = self.glasses else { continue }
                if !glasses.isStreaming { await glasses.startStreaming() }
                if let jpeg = glasses.currentFrameJPEG(maxWidth: 1024, quality: 0.7) {
                    self.client?.sendImage(jpeg, note: "")
                }
            }
        }
    }
}
