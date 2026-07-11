import SwiftUI
import DesignSystem
import GlassesKit
import Inject

/// The app root displays the home screen. Router-driven global sheets live here
/// so the wake word / Shortcuts can present over the active content.
struct RootTabView: View {
    @EnvironmentObject private var glasses: GlassesService
    @EnvironmentObject private var providers: ProviderManager
    @EnvironmentObject private var session: RealtimeSession
    @EnvironmentObject private var hermes: HermesService
    @EnvironmentObject private var router: AppRouter
    @ObserveInjection var inject

    var body: some View {
        ZStack {
            Theme.Palette.canvas.ignoresSafeArea()

            HomeView()
        }
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
                .environmentObject(hermes)
        }
        .preferredColorScheme(.light)
        .enableInjection()
    }
}
