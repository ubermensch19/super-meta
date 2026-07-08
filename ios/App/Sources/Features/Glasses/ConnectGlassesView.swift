import SwiftUI
import DesignSystem
import GlassesKit

/// Connect sheet — auto-presented from Home when the glasses aren't linked.
/// A single toggle drives DAT registration: on → link (hands off to the Meta AI
/// app), off → unlink. Mirrors turbometa's welcome/connect flow.
struct ConnectGlassesView: View {
    @EnvironmentObject private var glasses: GlassesService
    @Environment(\.dismiss) private var dismiss

    private var isLinked: Bool {
        glasses.registration == .registered || glasses.registration == .registering
    }

    private var statusLabel: String {
        if !glasses.isAvailable { return "Unavailable" }
        switch glasses.registration {
        case .registered: return glasses.hasActiveDevice ? "Glasses connected" : "Linked · turn on glasses"
        case .registering: return "Connecting…"
        default: return "Not linked"
        }
    }

    private var statusColor: Color {
        if glasses.hasActiveDevice { return Theme.Palette.positive }
        if glasses.registration == .registered { return Theme.Palette.accent }
        return Theme.Palette.textMuted
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer(minLength: Theme.Spacing.xl)

            Image("Logomark")
                .resizable().scaledToFit()
                .frame(height: 40)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Connect your glasses")
                    .font(Theme.Font.title(24))
                    .foregroundStyle(Theme.Palette.textPrimary)
                StatusBadge(statusLabel, color: statusColor)
            }

            // The connect toggle.
            HUDPanel {
                Toggle(isOn: Binding(
                    get: { isLinked },
                    set: { on in
                        Task { on ? await glasses.startRegistration() : await glasses.startUnregistration() }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connect to glasses")
                            .font(Theme.Font.body(16))
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text(isLinked ? "Linked to your Ray-Ban Meta glasses" : "Link Super Meta to your glasses")
                            .font(Theme.Font.readout(12))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                .tint(Theme.Palette.accent)
                .disabled(!glasses.isAvailable || glasses.registration == .registering)
            }

            Text(helperText)
                .font(Theme.Font.readout(13))
                .foregroundStyle(Theme.Palette.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)

            if let error = glasses.lastError {
                Text(error)
                    .font(Theme.Font.readout(12))
                    .foregroundStyle(Theme.Palette.live)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.lg)
            }

            Spacer()

            HUDButton(glasses.hasActiveDevice ? "Done" : "Continue") { dismiss() }
                .padding(.horizontal, Theme.Spacing.lg)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.canvas.ignoresSafeArea())
        // Dismiss automatically once the glasses are actively connected.
        .onChange(of: glasses.hasActiveDevice) { _, connected in
            if connected { dismiss() }
        }
    }

    private var helperText: String {
        if !glasses.isAvailable {
            return "Glasses SDK unavailable — run on a device with the Meta AI app and your credentials set."
        }
        switch glasses.registration {
        case .registered:
            return glasses.hasActiveDevice
                ? "You're all set."
                : "Linked. Put your glasses on or take them out of the case to connect."
        case .registering:
            return "Approve the connection in the Meta AI app, then come back."
        default:
            return "Turn on the toggle to link Super Meta with your glasses. You'll approve it once in the Meta AI app."
        }
    }
}
