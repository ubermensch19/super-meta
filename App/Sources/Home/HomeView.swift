import SwiftUI
import DesignSystem
import GlassesKit

/// The feature hub — an editorial layout with a hero action and grouped sections
/// rather than a uniform tile grid.
struct HomeView: View {
    @EnvironmentObject private var glasses: GlassesService
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    header

                    NavigationLink { LiveAIView() } label: { heroCard }
                        .buttonStyle(.plain)

                    section("See") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.md) {
                                compactCard("Quick Vision", "Recognize", "eye", Theme.Palette.accent) { QuickVisionView() }
                                compactCard("Vision Chat", "Ask anything", "bubble.left.and.text.bubble.right", Theme.Palette.positive) { VisionRecognitionView() }
                                compactCard("LeanEat", "Nutrition", "leaf", Theme.Palette.live) { LeanEatView() }
                            }
                            .padding(.horizontal, Theme.Spacing.lg)
                        }
                        .padding(.horizontal, -Theme.Spacing.lg)
                    }

                    section("Speak") {
                        NavigationLink { LiveTranslateView() } label: {
                            wideCard("Live Translate", "Real-time, across 11 languages", "globe", Theme.Palette.positive)
                        }.buttonStyle(.plain)
                    }

                    section("Connect") {
                        HStack(spacing: Theme.Spacing.md) {
                            NavigationLink { GatewayView() } label: {
                                tile("Agent Link", "OpenClaw · Hermes", "antenna.radiowaves.left.and.right", Theme.Palette.accent)
                            }.buttonStyle(.plain)
                            NavigationLink { RTMPStreamView() } label: {
                                tile("Live Stream", "Broadcast RTMP", "dot.radiowaves.left.and.right", Theme.Palette.live)
                            }.buttonStyle(.plain)
                        }
                    }

                    NavigationLink { RecordsView() } label: { recordsRow }
                        .buttonStyle(.plain)
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Palette.canvas.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Meta-Mod")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                connectionChip
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(10)
                    .background(Circle().fill(Theme.Palette.surface))
            }
        }
    }

    private var connectionChip: some View {
        HStack(spacing: 6) {
            Circle().fill(glasses.hasActiveDevice ? Theme.Palette.positive : Theme.Palette.textMuted).frame(width: 6, height: 6)
            Text(connectionText).font(.system(size: 12)).foregroundStyle(Theme.Palette.textSecondary)
            if glasses.isAvailable && glasses.registration != .registered {
                Button("Connect") { Task { await glasses.startRegistration() } }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Palette.accent)
            }
        }
    }

    private var connectionText: String {
        if !glasses.isAvailable { return "No glasses · using photos" }
        return glasses.hasActiveDevice ? "Glasses connected" : "Glasses not connected"
    }

    // MARK: Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "mic.fill").font(.system(size: 22))
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Theme.Palette.canvas)
            Spacer()
            Text("Live AI").font(.system(size: 26, weight: .bold)).foregroundStyle(Theme.Palette.canvas)
            Text("Talk to your glasses in real time — it sees and hears with you.")
                .font(.system(size: 14)).foregroundStyle(Theme.Palette.canvas.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [Theme.Palette.accent, Theme.Palette.live],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    // MARK: Section scaffolding

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Palette.textMuted)
            content()
        }
    }

    private func compactCard<D: View>(_ title: String, _ subtitle: String, _ icon: String, _ tint: Color, @ViewBuilder destination: @escaping () -> D) -> some View {
        NavigationLink { destination() } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                iconBadge(icon, tint)
                Spacer()
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.Palette.textPrimary)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.Palette.textSecondary)
            }
            .frame(width: 132, height: 132, alignment: .topLeading)
            .padding(Theme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.Palette.surface))
        }
        .buttonStyle(.plain)
    }

    private func wideCard(_ title: String, _ subtitle: String, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            iconBadge(icon, tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.Palette.textPrimary)
                Text(subtitle).font(.system(size: 13)).foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Palette.textMuted)
        }
        .padding(Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.Palette.surface))
    }

    private func tile(_ title: String, _ subtitle: String, _ icon: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            iconBadge(icon, tint)
            Spacer()
            Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.Palette.textPrimary)
            Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .padding(Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.Palette.surface))
    }

    private var recordsRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "clock.arrow.circlepath").font(.system(size: 16)).foregroundStyle(Theme.Palette.textSecondary)
            Text("History").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.Palette.textPrimary)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Palette.textMuted)
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    private func iconBadge(_ icon: String, _ tint: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: 38, height: 38)
            .background(Circle().fill(tint.opacity(0.14)))
    }
}
