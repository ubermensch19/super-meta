import SwiftUI
import SwiftData
import GlassesKit

@main
struct MetaModApp: App {
    @StateObject private var glasses: GlassesService
    @StateObject private var providers = ProviderManager.shared
    @StateObject private var gateway: GatewayService
    @StateObject private var router = AppRouter.shared

    init() {
        let glassesService = GlassesService()
        _glasses = StateObject(wrappedValue: glassesService)
        _gateway = StateObject(wrappedValue: GatewayService(glasses: glassesService))
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(glasses)
                .environmentObject(providers)
                .environmentObject(gateway)
                .environmentObject(router)
                .sheet(isPresented: $router.showQuickVision) {
                    NavigationStack { QuickVisionView() }
                        .environmentObject(glasses)
                        .environmentObject(providers)
                }
        }
        .modelContainer(for: VisionRecord.self)
    }
}
