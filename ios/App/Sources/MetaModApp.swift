import SwiftUI
import SwiftData
import GlassesKit

@main
struct MetaModApp: App {
    @StateObject private var glasses: GlassesService
    @StateObject private var providers = ProviderManager.shared
    @StateObject private var gateway: GatewayService
    @StateObject private var hermes: HermesService
    @StateObject private var router = AppRouter.shared
    /// One shared assistant session, used by the wake word AND by `LiveAIView`,
    /// so a wake-started conversation can exist without that screen being open.
    @StateObject private var session = RealtimeSession()
    @StateObject private var wakeListener = WakeWordListener.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let glassesService = GlassesService()
        let gatewayService = GatewayService(glasses: glassesService)
        _glasses = StateObject(wrappedValue: glassesService)
        _gateway = StateObject(wrappedValue: gatewayService)
        _hermes = StateObject(wrappedValue: HermesService(gateway: gatewayService))
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(glasses)
                .environmentObject(providers)
                .environmentObject(gateway)
                .environmentObject(hermes)
                .environmentObject(router)
                .environmentObject(session)
                .environmentObject(wakeListener)
                .sheet(isPresented: $router.showQuickVision) {
                    NavigationStack { QuickVisionView() }
                        .environmentObject(glasses)
                        .environmentObject(providers)
                }
                .sheet(isPresented: $router.liveAIWoke) {
                    NavigationStack { LiveAIView() }
                        .environmentObject(glasses)
                        .environmentObject(providers)
                        .environmentObject(session)
                }
                .onOpenURL { url in glasses.handleCallbackURL(url) }
                .onAppear(perform: configureWake)
        }
        .modelContainer(for: VisionRecord.self)
        .onChange(of: scenePhase) { _, phase in
            // Start listening when we come to the foreground; keep listening in the
            // background/locked (the active audio session keeps us alive). We only
            // stop when the user turns the toggle off.
            if phase == .active, wakeListener.enabled { wakeListener.start() }
        }
    }

    private func configureWake() {
        wakeListener.onWake = {
            router.liveAIWoke = true // surface the Live AI sheet if/when foregrounded
            if session.status == .idle {
                session.start(
                    instructions: LiveAIMode.standard.instructions,
                    providers: providers, glasses: glasses,
                    injectFrames: glasses.isAvailable)
            }
        }
        if wakeListener.enabled { wakeListener.start() }
    }
}
