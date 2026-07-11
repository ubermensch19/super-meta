import Foundation
import SwiftUI

extension Notification.Name {
    static let openQuickVision = Notification.Name("metamod.openQuickVision")
}

/// Lightweight router so App Intents / Shortcuts can drive in-app navigation.
@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()
    @Published var showQuickVision = false
    /// Set when the wake word fires so the app can surface the Live AI sheet
    /// (with the live transcript) when it's next foregrounded.
    @Published var liveAIWoke = false

    private init() {
        NotificationCenter.default.addObserver(
            forName: .openQuickVision, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.showQuickVision = true }
        }
    }
}
