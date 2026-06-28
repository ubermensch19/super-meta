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

    private var client: OpenAIRealtimeClient?
    private let audio = RealtimeAudioEngine()
    private var eventTask: Task<Void, Never>?
    private var frameTask: Task<Void, Never>?

    private var providers: ProviderManager?
    private var glasses: GlassesService?

    init() {}

    /// Starts a session. `injectFrames` periodically sends a glasses frame as visual context.
    func start(
        instructions: String,
        voice: String = "alloy",
        providers: ProviderManager,
        glasses: GlassesService,
        injectFrames: Bool = false
    ) {
        self.providers = providers
        self.glasses = glasses
        let key = providers.apiKey(for: .openAI)
        guard !key.isEmpty else {
            status = .error("Add your OpenAI API key in Settings — realtime voice uses OpenAI.")
            return
        }
        status = .connecting
        transcript = ""
        userLine = ""

        let client = OpenAIRealtimeClient(apiKey: key, config: .init(voice: voice, instructions: instructions, audio: true))
        self.client = client

        eventTask = Task { [weak self] in
            guard let self else { return }
            for await event in client.events {
                await self.handle(event)
            }
        }

        do {
            try audio.start { [weak client] chunk in client?.appendAudio(chunk) }
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
        case .responseDone:
            transcript += "\n"
        case let .error(message):
            status = .error(message)
        case .other:
            break
        }
    }

    private func startFrameInjection() {
        frameTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                guard let self, self.status == .live, let glasses = self.glasses else { continue }
                if !glasses.isStreaming { await glasses.startStreaming() }
                if let jpeg = glasses.currentFrameJPEG(maxWidth: 1024, quality: 0.7) {
                    self.client?.sendImage(jpeg)
                }
            }
        }
    }
}
