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
        let key = providers.realtimeAPIKey()
        guard !key.isEmpty else {
            status = .error("Add your Gemini API key in Settings for realtime voice.")
            return
        }
        status = .connecting
        transcript = ""
        userLine = ""
        responseInFlight = false
        pendingResponseCreate = false
        announcementQueue = []

        let config = RealtimeConfig(model: providers.realtimeModel, voice: voice, instructions: instructions, audio: true, tools: tools)
        // The wake listener and Gemini Live cannot own the glasses mic together.
        // Wait for its serial audio queue to finish teardown before starting Live.
        WakeWordListener.shared.pause { [weak self] in
            Task { @MainActor [weak self] in
                self?.beginGeminiLive(config: config, apiKey: key, injectFrames: injectFrames)
            }
        }
    }

    private func beginGeminiLive(config: RealtimeConfig, apiKey: String, injectFrames: Bool) {
        guard status == .connecting else { return }
        let client: any RealtimeClient = GeminiLiveClient(apiKey: apiKey, config: config)
        self.client = client

        eventTask = Task { [weak self] in
            guard let self else { return }
            for await event in client.events {
                self.handle(event)
            }
        }

        do {
            try audio.start(captureSampleRate: 16_000) { [weak client] chunk in client?.appendAudio(chunk) }
            client.connect()
            if injectFrames { startFrameInjection() }
        } catch {
            endWithError("Audio error: \(error.localizedDescription)")
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
            endWithError(message)
        case .other:
            break
        }
    }

    private func runTool(name: String, callID: String, argumentsJSON: String) {
        Task { @MainActor [weak self] in
            guard let self, let client = self.client else { return }
            let output: String
            if GlassesTools.all.contains(where: { $0.name == name }) {
                output = await self.handleGlassesTool(name: name, argumentsJSON: argumentsJSON, client: client)
            } else {
                output = await self.toolHandler?(name, argumentsJSON)
                    ?? #"{"error":"No agent is configured for tools"}"#
            }
            client.sendFunctionOutput(callID: callID, output: output)
            if self.responseInFlight {
                self.pendingResponseCreate = true
            } else {
                client.createResponse()
            }
        }
    }

    private func handleGlassesTool(name: String, argumentsJSON: String, client: any RealtimeClient) async -> String {
        guard let glasses else { return #"{"error":"Glasses are unavailable"}"# }
        switch name {
        case "glasses_start_camera":
            await glasses.startStreaming()
            return glasses.isStreaming ? #"{"status":"camera started"}"# : #"{"error":"Camera did not start"}"#
        case "glasses_stop_camera":
            await glasses.stopStreaming()
            return #"{"status":"camera stopped"}"#
        case "glasses_look", "glasses_take_photo":
            if !glasses.isStreaming { await glasses.startStreaming() }
            let image: Data?
            if let latest = glasses.currentFrameJPEG(maxWidth: 1280, quality: 0.75) {
                image = latest
            } else {
                image = try? await glasses.capturePhoto()
            }
            guard let image else { return #"{"error":"No glasses image is available. Make sure the glasses are connected and camera permission is granted."}"# }
            let args = (try? JSONSerialization.jsonObject(with: Data(argumentsJSON.utf8))) as? [String: Any]
            let note = args?["question"] as? String ?? (name == "glasses_look" ? "Describe exactly what is visible in this fresh glasses image." : "The wearer requested this photo. Confirm it was captured and describe it if useful.")
            client.sendImage(image, note: note)
            return #"{"status":"fresh glasses image sent to Gemini"}"#
        default:
            return #"{"error":"Unknown glasses tool"}"#
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

    /// A failed connection must release the microphone for the wake listener.
    /// Otherwise an invalid Live setup leaves "Hey Gemini" permanently paused.
    private func endWithError(_ message: String) {
        frameTask?.cancel(); frameTask = nil
        eventTask?.cancel(); eventTask = nil
        audio.stop()
        client?.disconnect()
        client = nil
        status = .error(message)
        WakeWordListener.shared.resume()
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
