import SwiftUI
import DesignSystem
import GlassesKit
import Inject

struct LiveTranslateView: View {
    @EnvironmentObject private var providers: ProviderManager
    @EnvironmentObject private var glasses: GlassesService
    @StateObject private var session = RealtimeSession()
    @ObserveInjection var inject

    @State private var source = "English"
    @State private var target = "Spanish"

    private let languages = ["English", "Spanish", "French", "German", "Italian", "Portuguese", "Japanese", "Korean", "Chinese", "Hindi", "Arabic"]

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            HUDPanel {
                HStack {
                    languageMenu("From", selection: $source)
                    Image(systemName: "arrow.right").foregroundStyle(Theme.Palette.accent)
                    languageMenu("To", selection: $target)
                }
            }
            HUDPanel {
                ScrollView {
                    Text(session.transcript.isEmpty ? statusText : session.transcript)
                        .font(Theme.Font.body(17))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
                }
            }
            Spacer()
            HUDButton(isActive ? "Stop" : "Start translating", systemImage: isActive ? "stop.fill" : "waveform") {
                if isActive { session.stop() }
                else { session.start(instructions: instructions, providers: providers, glasses: glasses) }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Palette.canvas.ignoresSafeArea())
        .navigationTitle("Live Translate")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .enableInjection()
        .onDisappear { session.stop() }
    }

    private var instructions: String {
        "You are a real-time interpreter. Listen to speech in \(source) and immediately speak only the \(target) translation. Do not add commentary. If you hear \(target), translate it to \(source)."
    }

    private var isActive: Bool { session.status == .live || session.status == .connecting }
    private var statusText: String {
        switch session.status {
        case .idle: return "Pick languages and tap Start. Speak, and hear the translation."
        case .connecting: return "Connecting…"
        case .live: return "Listening…"
        case let .error(message): return message
        }
    }

    private func languageMenu(_ label: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(Theme.Font.readout(10)).foregroundStyle(Theme.Palette.textMuted)
            Menu {
                ForEach(languages, id: \.self) { lang in
                    Button(lang) { selection.wrappedValue = lang }
                }
            } label: {
                Text(selection.wrappedValue).font(Theme.Font.title(16)).foregroundStyle(Theme.Palette.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
