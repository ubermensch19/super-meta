import SwiftUI
import SwiftData
import GlassesKit

@main
struct MetaModApp: App {
    @StateObject private var glasses = GlassesService()
    @StateObject private var providers = ProviderManager.shared

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(glasses)
                .environmentObject(providers)
        }
        .modelContainer(for: VisionRecord.self)
    }
}
