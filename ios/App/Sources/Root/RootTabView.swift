import SwiftUI
import DesignSystem
import GlassesKit
import Inject

/// The app root: three tabs behind a floating pill nav. Each tab owns its own
/// NavigationStack so back-navigation stays independent. The two router-driven
/// global sheets live here so the wake word / Shortcuts can present over any tab.
struct RootTabView: View {
    @EnvironmentObject private var glasses: GlassesService
    @EnvironmentObject private var providers: ProviderManager
    @EnvironmentObject private var session: RealtimeSession
    @EnvironmentObject private var hermes: HermesService
    @EnvironmentObject private var router: AppRouter
    @State private var selection = RootTabView.initialSelection
    @ObserveInjection var inject

    /// Debug-only: `UI_TAB=activity|profile` opens straight to a tab for QA screenshots.
    private static var initialSelection: Int {
        switch ProcessInfo.processInfo.environment["UI_TAB"] {
        case "activity": return 1
        case "profile": return 2
        default: return 0
        }
    }

    private let tabs = [
        TabBarItem(systemImage: "house.fill", title: "Home"),
        TabBarItem(systemImage: "waveform.path.ecg", title: "Activity"),
        TabBarItem(systemImage: "person.fill", title: "Profile"),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Palette.canvas.ignoresSafeArea()

            Group {
                switch selection {
                case 1: ActivityView()
                case 2: SettingsView(showsDoneButton: false)
                default: HomeView()
                }
            }

            FloatingTabBar(items: tabs, selection: $selection)
                .padding(.bottom, Theme.Spacing.sm)
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
