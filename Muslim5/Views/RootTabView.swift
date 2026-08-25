import SwiftUI

struct RootTabView: View {
    @State private var selectedTab = AppTab.today

    private enum AppTab: Hashable {
        case today
        case journey
        case settings
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            tabs
                .tabBarMinimizeBehavior(.onScrollDown)
        } else {
            tabs
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "circle.grid.2x2.fill")
                }
                .tag(AppTab.today)

            JourneyView()
                .tabItem {
                    Label("Journey", systemImage: "square.grid.3x3.fill")
                }
                .tag(AppTab.journey)

            SettingsView()
                .tabItem {
                    Label("You", systemImage: "person.crop.circle")
                }
                .tag(AppTab.settings)
        }
        .onChange(of: selectedTab) {
            HapticFeedback.selection()
        }
    }
}
