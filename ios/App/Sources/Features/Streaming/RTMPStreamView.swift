import SwiftUI
import DesignSystem
import GlassesKit
import Inject

/// The Live Stream screen: a full-bleed preview of the glasses camera with a HUD
/// overlay for picking a destination and broadcasting it over RTMP. The camera
/// starts on appear so the preview is live before the user goes live.
struct RTMPStreamView: View {
    @EnvironmentObject private var glasses: GlassesService
    @StateObject private var service = RTMPService()
    @ObserveInjection var inject

    @AppStorage("rtmp_url") private var url = ""
    @AppStorage("rtmp_platform") private var platformRaw = StreamingPlatform.custom.rawValue
    @AppStorage("rtmp_bitrate") private var bitrate = 2_000_000
    @State private var streamKey = ""
    @State private var chromeVisible = true

    private let bitrateOptions = [1_000_000, 2_000_000, 3_000_000, 4_000_000]

    var body: some View {
        ZStack {
            preview
            scrim
            VStack(spacing: Theme.Spacing.md) {
                topBar
                Spacer(minLength: 0)
                if chromeVisible { controls.transition(.move(edge: .bottom).combined(with: .opacity)) }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.Palette.canvas.ignoresSafeArea())
        .navigationTitle("Live Stream")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .contentShape(Rectangle())
        .onTapGesture { if isStreaming { withAnimation(.easeInOut(duration: 0.2)) { chromeVisible.toggle() } } }
        .task { streamKey = KeychainStore.get("rtmp_stream_key") ?? "" }
        .onAppear { Task { await glasses.startStreaming() } }
        .onDisappear {
            service.stop()
            Task { await glasses.stopStreaming() }
        }
        .onChange(of: service.state) { _, state in
            if state != .streaming, state != .connecting { chromeVisible = true }
        }
        .enableInjection()
    }

    // MARK: - Preview

    private var preview: some View {
        Group {
            if let frame = glasses.latestFrame {
                Image(uiImage: frame)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .ignoresSafeArea()
    }

    private var placeholder: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "video.slash")
                .font(.system(size: 40))
                .foregroundStyle(Theme.Palette.textMuted)
            Text(glasses.hasActiveDevice
                 ? "Waiting for the glasses camera…"
                 : "Connect your glasses to see the live feed.")
                .font(Theme.Font.body(14))
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
            if glasses.hasActiveDevice { ProgressView().tint(Theme.Palette.accent) }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.canvas)
    }

    private var scrim: some View {
        LinearGradient(
            colors: [.black.opacity(0.55), .clear, .clear, .black.opacity(0.7)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Top bar (status + stats)

    private var topBar: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                StatusBadge(statusLabel, color: statusColor)
                if service.state == .streaming { recordIndicator }
                Spacer()
            }
            if service.state == .streaming { statsBar }
        }
    }

    private var recordIndicator: some View {
        HStack(spacing: 6) {
            BlinkingDot()
            Text("REC").font(Theme.Font.readout(11)).tracking(1.2).foregroundStyle(Theme.Palette.live)
        }
        .padding(.horizontal, Theme.Spacing.md).padding(.vertical, Theme.Spacing.sm)
        .background(Capsule().fill(Theme.Palette.surface.opacity(0.7)))
        .overlay(Capsule().strokeBorder(Theme.Palette.border, lineWidth: 1))
    }

    private var statsBar: some View {
        HUDPanel {
            HStack {
                stat("FPS", String(format: "%.0f", service.fps))
                statDivider
                stat("FRAMES", "\(service.framesSent)")
                statDivider
                stat("TIME", timeString(service.connectionTime))
            }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        HUDPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if !isStreaming {
                    presetRow
                    field("RTMP URL", text: $url)
                    field("Stream key", text: $streamKey, secure: true)
                    bitrateRow
                }
                goLiveButton
                if case let .error(message) = service.state {
                    Text(message)
                        .font(Theme.Font.body(13))
                        .foregroundStyle(Theme.Palette.live)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var presetRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(StreamingPlatform.allCases) { platform in
                    let selected = self.platform == platform
                    Button { select(platform) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: platform.icon).font(.system(size: 12))
                            Text(platform.displayName).font(Theme.Font.readout(12))
                        }
                        .padding(.horizontal, Theme.Spacing.md).padding(.vertical, Theme.Spacing.sm)
                        .background(Capsule().fill(selected ? Theme.Palette.accent.opacity(0.22) : Theme.Palette.surface))
                        .foregroundStyle(selected ? Theme.Palette.accent : Theme.Palette.textSecondary)
                        .overlay(Capsule().strokeBorder(selected ? Theme.Palette.accent.opacity(0.6) : .clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var bitrateRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("BITRATE").font(Theme.Font.readout(10)).tracking(1).foregroundStyle(Theme.Palette.textMuted)
            Picker("Bitrate", selection: $bitrate) {
                ForEach(bitrateOptions, id: \.self) { value in
                    Text("\(value / 1_000_000) Mbps").tag(value)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var goLiveButton: some View {
        HUDButton(isStreaming ? "Stop streaming" : "Go live",
                  systemImage: isStreaming ? "stop.fill" : "dot.radiowaves.left.and.right") {
            if isStreaming {
                service.stop()
            } else {
                KeychainStore.set(streamKey, for: "rtmp_stream_key")
                service.start(url: url, streamKey: streamKey, bitrate: bitrate, glasses: glasses)
            }
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

    // MARK: - Derived state

    private var platform: StreamingPlatform {
        StreamingPlatform(rawValue: platformRaw) ?? .custom
    }

    private var isStreaming: Bool {
        service.state == .streaming || service.state == .connecting
    }

    private func select(_ platform: StreamingPlatform) {
        platformRaw = platform.rawValue
        if platform != .custom { url = platform.defaultURL }
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

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Theme.Font.readout(15)).foregroundStyle(Theme.Palette.textPrimary)
            Text(label).font(Theme.Font.readout(9)).tracking(1).foregroundStyle(Theme.Palette.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle().fill(Theme.Palette.border).frame(width: 1, height: 24)
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

/// A pulsing red dot for the "recording" indicator.
private struct BlinkingDot: View {
    @State private var on = false
    var body: some View {
        Circle()
            .fill(Theme.Palette.live)
            .frame(width: 8, height: 8)
            .opacity(on ? 1 : 0.25)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { on = true }
            }
    }
}
