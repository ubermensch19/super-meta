import SwiftUI
import SwiftData
import DesignSystem
import GlassesKit
import Inject

/// The feature hub — a light "NEURA" dashboard: a hero Live AI card, real-data
/// stat cards, and grouped feature sections.
struct HomeView: View {
    @EnvironmentObject private var glasses: GlassesService
    @Query(sort: \VisionRecord.createdAt, order: .reverse) private var records: [VisionRecord]
    @State private var showSettings = false
    @State private var showConnect = false
    @State private var connectShownOnce = false
    @ObserveInjection var inject

    /// Auto-present the connect sheet once per launch when the glasses aren't linked.
    private func maybeShowConnect() {
        if ProcessInfo.processInfo.environment["UI_PREVIEW"] != nil { return }
        guard glasses.isAvailable, glasses.registration == .notRegistered, !connectShownOnce else { return }
        connectShownOnce = true
        showConnect = true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    header

                    NavigationLink { LiveAIView() } label: { heroCard }
                        .buttonStyle(.plain)

                    statRow

                    section("Connect") {
                        VStack(spacing: Theme.Spacing.md) {
                            NavigationLink { HermesView() } label: {
                                wideCard("Hermes", "Command your agent — tasks, messages, status", "command", Theme.Palette.ink)
                            }.buttonStyle(.plain)
                            HStack(spacing: Theme.Spacing.md) {
                                NavigationLink { GatewayView() } label: {
                                    tile("Agent Link", "Camera node", "antenna.radiowaves.left.and.right", Theme.Palette.positive)
                                }.buttonStyle(.plain)
                                NavigationLink { RTMPStreamView() } label: {
                                    tile("Live Stream", "Broadcast RTMP", "dot.radiowaves.left.and.right", Theme.Palette.live)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Palette.canvas.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showConnect) {
                ConnectGlassesView().environmentObject(glasses)
            }
            .onAppear { maybeShowConnect() }
            .onChange(of: glasses.registration) { _, _ in maybeShowConnect() }
        }
        .preferredColorScheme(.light)
        .enableInjection()
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image("Logomark")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 26)
                    Text("Super Meta")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
                connectionChip
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Theme.Palette.surface))
                    .overlay(Circle().strokeBorder(Theme.Palette.border, lineWidth: 1))
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
            }
        }
    }

    private var connectionChip: some View {
        HStack(spacing: 6) {
            Circle().fill(dotColor).frame(width: 6, height: 6)
            Text(connectionText).font(.system(size: 12)).foregroundStyle(Theme.Palette.textSecondary)
            if glasses.isAvailable && glasses.registration != .registered {
                Button(glasses.registration == .registering ? "Connecting…" : "Connect") {
                    showConnect = true
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .disabled(glasses.registration == .registering)
            }
        }
    }

    private var dotColor: Color {
        if glasses.hasActiveDevice { return Theme.Palette.positive }
        if glasses.registration == .registered { return Theme.Palette.accent }
        return Theme.Palette.textMuted
    }

    private var connectionText: String {
        if !glasses.isAvailable { return "No glasses · using photos" }
        switch glasses.registration {
        case .registered:
            return glasses.hasActiveDevice ? "Glasses connected" : "Linked · turn on glasses"
        case .registering:
            return "Connecting…"
        default:
            return "Glasses not linked"
        }
    }

    // MARK: Hero

    private var heroCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top) {
                    StatusBadge(glasses.hasActiveDevice ? "Live" : "Standby", color: dotColor)
                    Spacer()
                    heroGlyph
                }
                Spacer(minLength: Theme.Spacing.md)
                Text("Live AI")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("Talk to your glasses in real time — it sees and hears with you.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Theme.Spacing.sm) {
                    Text("Start Live AI")
                        .font(.system(size: 15, weight: .semibold))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.md)
                .background(Capsule().fill(Theme.Palette.ink))
                .padding(.top, Theme.Spacing.xs)
            }
            .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        }
    }

    /// The glasses' latest camera frame if we have one, otherwise a mic glyph.
    @ViewBuilder private var heroGlyph: some View {
        if let frame = glasses.latestFrame {
            Image(uiImage: frame)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        } else {
            Image(systemName: "mic.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Theme.Palette.surfaceHigh))
        }
    }

    // MARK: Stat row (real data only)

    private var statRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            StatCard(value: "\(records.count)", label: "Records", systemImage: "square.stack.3d.up")
            StatCard(value: "\(weekCount)", label: "This week", systemImage: "calendar")
            StatCard(
                value: connectionValue,
                label: "Glasses",
                tint: glasses.hasActiveDevice ? Theme.Palette.positive : Theme.Palette.textSecondary,
                systemImage: "eyeglasses"
            )
        }
    }

    private var weekCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return records.filter { $0.createdAt >= cutoff }.count
    }

    private var connectionValue: String {
        if glasses.hasActiveDevice { return "Live" }
        if glasses.registration == .registered { return "Linked" }
        return "Off"
    }

    // MARK: Section scaffolding

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Palette.textSecondary)
            content()
        }
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
        .modifier(CardSurface())
    }

    private func tile(_ title: String, _ subtitle: String, _ icon: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            iconBadge(icon, tint)
            Spacer()
            Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.Palette.textPrimary)
            Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .modifier(CardSurface())
    }

    private func iconBadge(_ icon: String, _ tint: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(tint == Theme.Palette.ink ? Color.white : tint)
            .frame(width: 38, height: 38)
            .background(Circle().fill(tint == Theme.Palette.ink ? Theme.Palette.ink : tint.opacity(0.14)))
    }
}

/// White card chrome shared by the Home tiles — surface fill, hairline border, soft shadow.
private struct CardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .fill(Theme.Palette.surface)
                    .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(Theme.Palette.border, lineWidth: 1)
            )
    }
}
