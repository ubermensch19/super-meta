import SwiftUI
import DesignSystem

/// Phase 0 placeholder — the "hello HUD" screen that proves the design system,
/// app target, and module wiring all build and render. Replaced in Phase 1 by the
/// glasses connection + feature shell.
struct RootView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "eye.circle")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundStyle(Theme.Palette.accent)

                Text("META-MOD")
                    .font(Theme.Font.display(40))
                    .tracking(4)
                    .foregroundStyle(Theme.Palette.textPrimary)

                Text("Smart-glasses AI, your way")
                    .font(Theme.Font.readout(13))
                    .tracking(2)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }

            HUDPanel {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack {
                        StatusBadge("scaffold", color: Theme.Palette.positive)
                        Spacer()
                        Text("v0.0.1")
                            .font(Theme.Font.readout(12))
                            .foregroundStyle(Theme.Palette.textMuted)
                    }
                    Text("Phase 0 complete — design system + app shell online. Glasses, providers, and features come next.")
                        .font(Theme.Font.body(15))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Spacer()

            HUDButton("Get started", systemImage: "arrow.right") {
                // Wired up in Phase 1 (onboarding / glasses registration).
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .hudCanvas()
    }
}

#Preview {
    RootView()
}
