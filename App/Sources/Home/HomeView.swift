import SwiftUI
import DesignSystem
import GlassesKit

/// The feature hub. Tiles route to each capability; a banner surfaces glasses status.
struct HomeView: View {
    @EnvironmentObject private var glasses: GlassesService
    @State private var showSettings = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    statusBanner
                    LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                        FeatureTile(title: "Live AI", subtitle: "Talk in real time", icon: "mic.fill", tint: Theme.Palette.live) {
                            LiveAIView()
                        }
                        FeatureTile(title: "Live Translate", subtitle: "Speak across languages", icon: "globe", tint: Theme.Palette.positive) {
                            LiveTranslateView()
                        }
                        FeatureTile(title: "Quick Vision", subtitle: "Recognize what you see", icon: "eye", tint: Theme.Palette.accent) {
                            QuickVisionView()
                        }
                        FeatureTile(title: "Vision Chat", subtitle: "Ask about an image", icon: "bubble.left.and.text.bubble.right", tint: Theme.Palette.positive) {
                            VisionRecognitionView()
                        }
                        FeatureTile(title: "LeanEat", subtitle: "Food & nutrition", icon: "leaf", tint: Theme.Palette.live) {
                            LeanEatView()
                        }
                        FeatureTile(title: "Agent Link", subtitle: "OpenClaw / Hermes", icon: "antenna.radiowaves.left.and.right", tint: Theme.Palette.accent) {
                            GatewayView()
                        }
                        FeatureTile(title: "Records", subtitle: "Your history", icon: "clock.arrow.circlepath", tint: Theme.Palette.textSecondary) {
                            RecordsView()
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Palette.canvas.ignoresSafeArea())
            .navigationTitle("Meta-Mod")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape").foregroundStyle(Theme.Palette.accent)
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private var statusBanner: some View {
        HUDPanel {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: glasses.hasActiveDevice ? "eyeglasses" : "eyeglasses.slash")
                    .foregroundStyle(glasses.hasActiveDevice ? Theme.Palette.positive : Theme.Palette.textMuted)
                VStack(alignment: .leading, spacing: 2) {
                    Text(bannerTitle).font(Theme.Font.title(15)).foregroundStyle(Theme.Palette.textPrimary)
                    Text(bannerSubtitle).font(Theme.Font.readout(12)).foregroundStyle(Theme.Palette.textSecondary)
                }
                Spacer()
                if glasses.isAvailable && glasses.registration != .registered {
                    Button("Connect") { Task { await glasses.startRegistration() } }
                        .buttonStyle(.bordered).tint(Theme.Palette.accent)
                }
            }
        }
    }

    private var bannerTitle: String {
        if !glasses.isAvailable { return "Glasses unavailable" }
        return glasses.hasActiveDevice ? "Glasses connected" : "No glasses connected"
    }
    private var bannerSubtitle: String {
        glasses.isAvailable ? "Features can also use a photo from your library." : "Set Meta credentials and run on a device for live glasses."
    }
}

struct FeatureTile<Destination: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(tint)
                Spacer()
                Text(title).font(Theme.Font.title(17)).foregroundStyle(Theme.Palette.textPrimary)
                Text(subtitle).font(Theme.Font.readout(11)).foregroundStyle(Theme.Palette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 130)
            .padding(Theme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Palette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
