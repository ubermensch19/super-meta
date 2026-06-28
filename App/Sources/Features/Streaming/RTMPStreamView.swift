import SwiftUI
import DesignSystem
import GlassesKit
import Inject

struct RTMPStreamView: View {
    @EnvironmentObject private var glasses: GlassesService
    @StateObject private var service = RTMPService()
    @ObserveInjection var inject

    @AppStorage("rtmp_url") private var url = ""
    @State private var streamKey = ""

    private let presets: [(String, String)] = [
        ("YouTube", "rtmp://a.rtmp.youtube.com/live2"),
        ("Twitch", "rtmp://live.twitch.tv/app"),
        ("Custom", "")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                HUDPanel {
                    HStack {
                        StatusBadge(statusLabel, color: statusColor)
                        Spacer()
                        Text("\(service.framesSent) frames")
                            .font(Theme.Font.readout(12)).foregroundStyle(Theme.Palette.textSecondary)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(presets, id: \.0) { name, value in
                            Button(name) { if !value.isEmpty { url = value } }
                                .font(Theme.Font.readout(12))
                                .padding(.horizontal, Theme.Spacing.md).padding(.vertical, Theme.Spacing.sm)
                                .background(Capsule().fill(Theme.Palette.surface))
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .buttonStyle(.plain)
                        }
                    }
                }

                field("RTMP URL", text: $url)
                field("Stream key", text: $streamKey, secure: true)

                HUDButton(isStreaming ? "Stop streaming" : "Go live", systemImage: isStreaming ? "stop.fill" : "dot.radiowaves.left.and.right") {
                    if isStreaming { service.stop() }
                    else { service.start(url: url, streamKey: streamKey, glasses: glasses) }
                }

                if case let .error(message) = service.state {
                    HUDPanel { Text(message).font(Theme.Font.body(14)).foregroundStyle(Theme.Palette.live) }
                }
                Text("Streams your glasses camera to any RTMP destination. Requires connected glasses.")
                    .font(Theme.Font.body(13)).foregroundStyle(Theme.Palette.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.Palette.canvas.ignoresSafeArea())
        .navigationTitle("Live Stream")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .enableInjection()
        .onDisappear { service.stop() }
    }

    private var isStreaming: Bool {
        service.state == .streaming || service.state == .connecting
    }
    private var statusLabel: String {
        switch service.state {
        case .idle: return "offline"
        case .connecting: return "connecting"
        case .streaming: return "live"
        case .error: return "error"
        }
    }
    private var statusColor: Color {
        switch service.state {
        case .streaming: return Theme.Palette.live
        case .connecting: return Theme.Palette.accent
        case .error: return Theme.Palette.live
        case .idle: return Theme.Palette.textMuted
        }
    }

    private func field(_ title: String, text: Binding<String>, secure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title.uppercased()).font(Theme.Font.readout(10)).tracking(1).foregroundStyle(Theme.Palette.textMuted)
            Group {
                if secure { SecureField(title, text: text) } else { TextField(title, text: text) }
            }
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .padding(Theme.Spacing.md)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
            .foregroundStyle(Theme.Palette.textPrimary)
        }
    }
}
