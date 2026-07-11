import SwiftUI
import GlassesKit

@main
struct MetaModApp: App {
    @StateObject private var glasses = GlassesService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(glasses)
        }
    }
}
