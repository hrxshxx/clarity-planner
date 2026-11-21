import SwiftUI
import Combine

@main
struct ClarityPlannerApp: App {
    @State private var planner = Planner()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Appearance.key) private var appearance = Appearance.system

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(planner)
                .tint(.brand)
                .onChange(of: appearance, initial: true) { _, new in new.apply() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { planner.rollOverIfNeeded() }
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
                    planner.rollOverIfNeeded()
                }
        }
    }
}

enum AppTab: Hashable { case today, goals, week, days, payoff }

/// Light/dark choice, kept per device in UserDefaults. `system` follows the phone's setting.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    static let key = "appearance"
    var id: Self { self }
    var label: String { rawValue.capitalized }

    /// Sets the window's style rather than using `preferredColorScheme`: going back to nil (system)
    /// with that modifier left open sheets stuck in the old mode.
    @MainActor func apply() {
        let style: UIUserInterfaceStyle = self == .light ? .light : self == .dark ? .dark : .unspecified
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.windows.forEach { $0.overrideUserInterfaceStyle = style }
        }
    }
    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
}

struct RootView: View {
    @State private var tab = AppTab.today
    @State private var showTimer = false

    var body: some View {
        TabView(selection: $tab) {
            Tab("Today", systemImage: "sun.max.fill", value: .today) {
                TodayView()
            }
            Tab("Goals", systemImage: "target", value: .goals) { GoalsView() }
            Tab("Week", systemImage: "chart.bar.fill", value: .week) { WeekView() }
            Tab("30 Days", systemImage: "square.grid.3x3.fill", value: .days) { ThirtyDaysView() }
            Tab("Payoff", systemImage: "arrow.up.arrow.down", value: .payoff) { PayoffView() }
            // The design's add circle used the Search slot, but iPhone caps tab bars at 5 incl. Search,
            // so a 6th tab overflowed into "More". Add lives in the Today toolbar instead.
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory { TimerAccessory(showSheet: $showTimer) }
        .sheet(isPresented: $showTimer) {
            TimerSheet().presentationDetents([.height(400)])
        }
    }
}
