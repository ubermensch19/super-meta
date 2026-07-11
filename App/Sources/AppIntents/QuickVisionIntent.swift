import AppIntents
import Foundation

/// Siri / Shortcuts entry point. Opens Meta-Mod straight into Quick Vision so the
/// user can recognize what they're looking at hands-free.
struct QuickVisionIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick Vision"
    static let description = IntentDescription("Recognize what you're looking at through your glasses.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        NotificationCenter.default.post(name: .openQuickVision, object: nil)
        return .result(dialog: "Opening Quick Vision.")
    }
}

struct MetaModShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickVisionIntent(),
            phrases: [
                "Quick Vision in \(.applicationName)",
                "Recognize this with \(.applicationName)",
                "What am I looking at with \(.applicationName)"
            ],
            shortTitle: "Quick Vision",
            systemImageName: "eye"
        )
    }
}
