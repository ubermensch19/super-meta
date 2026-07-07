import SwiftUI

/// Super Meta design tokens — a dark, cinematic heads-up-display aesthetic.
/// Deliberately distinct: near-black canvas, warm amber signal accent, mono data readouts.
public enum Theme {

    // MARK: - Color

    public enum Palette {
        /// Base canvas — near-black.
        public static let canvas = Color(hex: "0B0B0F")
        /// Elevated glass surface.
        public static let surface = Color(hex: "16161D")
        /// Higher elevation / pressed surface.
        public static let surfaceHigh = Color(hex: "20212B")
        /// Hairline borders on glass.
        public static let border = Color(hex: "2E2F3A")

        /// Primary signal accent — warm amber.
        public static let accent = Color(hex: "FFA62B")
        /// Live / recording state.
        public static let live = Color(hex: "FF4D8D")
        /// Positive / connected.
        public static let positive = Color(hex: "39E0A0")

        public static let textPrimary = Color(hex: "F4F4F6")
        public static let textSecondary = Color(hex: "9A9BA6")
        public static let textMuted = Color(hex: "61626C")
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
