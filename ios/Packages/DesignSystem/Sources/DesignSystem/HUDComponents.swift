import SwiftUI

/// A white glass panel with a soft shadow — the building block for cards and controls.
public struct HUDPanel<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(Theme.Palette.surface)
                    .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(Theme.Palette.border, lineWidth: 1)
            )
    }
}

/// A small status pill with a colored dot — used for connection / live state.
public struct StatusBadge: View {
    private let label: String
    private let color: Color

    public init(_ label: String, color: Color = Theme.Palette.textSecondary) {
        self.label = label
        self.color = color
    }

    public var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label.uppercased())
                .font(Theme.Font.readout(11))
                .tracking(1.2)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            Capsule().fill(Theme.Palette.surface)
        )
        .overlay(
            Capsule().strokeBorder(Theme.Palette.border, lineWidth: 1)
        )
    }
}

/// Primary call-to-action — a near-black "ink" pill with white text.
public struct HUDButton: View {
    private let title: String
    private let systemImage: String?
    private let action: () -> Void

    public init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(Theme.Font.title(17))
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(Theme.Palette.ink)
                    .shadow(color: Theme.Palette.ink.opacity(0.18), radius: 10, x: 0, y: 5)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Applies the app's canvas background, edge to edge.
public struct CanvasBackground: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background(Theme.Palette.canvas.ignoresSafeArea())
            .preferredColorScheme(.light)
    }
}

public extension View {
    func hudCanvas() -> some View { modifier(CanvasBackground()) }
}
