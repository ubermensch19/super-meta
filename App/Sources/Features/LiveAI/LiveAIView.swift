import SwiftUI
import DesignSystem
import GlassesKit
import Inject

struct LiveAIView: View {
    @EnvironmentObject private var providers: ProviderManager
    @EnvironmentObject private var glasses: GlassesService
    @StateObject private var session = RealtimeSession()
    @State private var mode: LiveAIMode = .standard
    @ObserveInjection var inject

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            modePicker
            transcriptArea
            Spacer()
            controlButton
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Palette.canvas.ignoresSafeArea())
        .navigationTitle("Live AI")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .enableInjection()
        .onDisappear { session.stop() }
    }

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(LiveAIMode.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .disabled(session.status == .live || session.status == .connecting)
    }

    private var transcriptArea: some View {
        HUDPanel {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    if !session.userLine.isEmpty {
                        Text("You: \(session.userLine)")
                            .font(Theme.Font.readout(12))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    Text(session.transcript.isEmpty ? statusText : session.transcript)
                        .font(Theme.Font.body(16))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
        }
    }

    private var statusText: String {
        switch session.status {
        case .idle: return "Tap Start, then just talk. The assistant replies out loud."
        case .connecting: return "Connecting…"
        case .live: return "Listening…"
        case let .error(message): return message
        }
    }

    private var controlButton: some View {
        HUDButton(buttonTitle, systemImage: isActive ? "stop.fill" : "mic.fill") {
            if isActive { session.stop() }
            else { session.start(instructions: mode.instructions, providers: providers, glasses: glasses, injectFrames: glasses.isAvailable) }
        }
    }

    private var isActive: Bool { session.status == .live || session.status == .connecting }
    private var buttonTitle: String { isActive ? "Stop" : "Start" }
}

enum LiveAIMode: String, CaseIterable, Identifiable {
    case standard, museum, accessibility
    var id: String { rawValue }
    var title: String {
        switch self {
        case .standard: return "Chat"
        case .museum: return "Guide"
        case .accessibility: return "Assist"
        }
    }
    var instructions: String {
        switch self {
        case .standard:
            return "You are a helpful voice assistant for someone wearing smart glasses. Keep replies short and conversational. You may receive images from their camera as context."
        case .museum:
            return "You are a knowledgeable museum and travel guide. When you see an image of an artwork, landmark, or object, explain what it is and share interesting context. Keep it concise and spoken-friendly."
        case .accessibility:
            return "You assist a visually impaired person wearing camera glasses. Describe scenes, read text, identify objects and hazards clearly and practically when you receive an image."
        }
    }
}
