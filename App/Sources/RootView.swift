import SwiftUI
import DesignSystem
import GlassesKit

/// Phase 1 shell — surfaces live glasses registration/connection status from
/// `GlassesService` and offers the registration entry point. The full feature
/// hub replaces this as later phases land.
struct RootView: View {
    @EnvironmentObject private var glasses: GlassesService

    private var statusLabel: String {
        switch glasses.registration {
        case .registered: return glasses.hasActiveDevice ? "connected" : "registered"
        case .registering: return "registering"
        case .notRegistered: return "not registered"
        case .unknown: return "checking"
        }
    }

    private var statusColor: Color {
        switch glasses.registration {
        case .registered: return glasses.hasActiveDevice ? Theme.Palette.positive : Theme.Palette.accent
        case .registering: return Theme.Palette.accent
        default: return Theme.Palette.textMuted
        }
    }

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
                        StatusBadge(statusLabel, color: statusColor)
                        Spacer()
                        Text("v0.0.1")
                            .font(Theme.Font.readout(12))
                            .foregroundStyle(Theme.Palette.textMuted)
                    }
                    if let error = glasses.lastError {
                        Text(error)
                            .font(Theme.Font.body(14))
                            .foregroundStyle(Theme.Palette.live)
                    } else {
                        Text("Connect your Ray-Ban Meta glasses to begin. Vision and voice features unlock once a device is paired.")
                            .font(Theme.Font.body(15))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Spacer()

            HUDButton(
                glasses.registration == .registered ? "Connected" : "Connect glasses",
                systemImage: glasses.registration == .registered ? "checkmark" : "link"
            ) {
                Task { await glasses.startRegistration() }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
            .disabled(glasses.registration == .registering)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .hudCanvas()
    }
}
