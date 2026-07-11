import SwiftUI

/// Super Meta design tokens — a light, glassmorphic "NEURA" aesthetic.
/// Off-white canvas, white glass cards with soft shadows, a near-black "ink" for
/// primary actions, and a single restrained highlight accent.
public enum Theme {

    // MARK: - Color

    public enum Palette {
        /// Base canvas — off-white.
        public static let canvas = Color(hex: "F0F0F2")
        /// White glass card base.
        public static let surface = Color(hex: "FFFFFF")
        /// Higher elevation / pressed surface.
        public static let surfaceHigh = Color(hex: "E8E8EC")
        /// Hairline dividers / card borders.
        public static let border = Color(hex: "E2E2E7")

        /// Near-black — primary buttons and the active tab.
        public static let ink = Color(hex: "111114")
        /// Restrained highlight accent — used for icon tints / small emphasis.
        public static let accent = Color(hex: "3A3A3C")
        /// Live / recording state.
        public static let live = Color(hex: "FF4D8D")
        /// Positive / connected (darker green for AA contrast on white).
        public static let positive = Color(hex: "10B981")

        public static let textPrimary = Color(hex: "0B0B0F")
        public static let textSecondary = Color(hex: "6B6C76")
        public static let textMuted = Color(hex: "9A9BA6")
    }

    // MARK: - Typography

    public enum Font {
        public static func display(_ size: CGFloat = 34) -> SwiftUI.Font {
            .system(size: size, weight: .bold, design: .default)
        }
        public static func title(_ size: CGFloat = 22) -> SwiftUI.Font {
            .system(size: size, weight: .semibold, design: .default)
        }
        public static func body(_ size: CGFloat = 17) -> SwiftUI.Font {
            .system(size: size, weight: .regular, design: .default)
        }
        /// Monospaced readout for HUD data (FPS, latency, numbers).
        public static func readout(_ size: CGFloat = 13) -> SwiftUI.Font {
            .system(size: size, weight: .medium, design: .monospaced)
        }
    }

    // MARK: - Spacing

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
    }

    // MARK: - Radius

    public enum Radius {
        public static let sm: CGFloat = 10
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let pill: CGFloat = 999
    }
}
