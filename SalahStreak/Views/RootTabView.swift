import SwiftUI

struct RootTabView: View {
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
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "circle.grid.2x2.fill")
                }

            JourneyView()
                .tabItem {
                    Label("Journey", systemImage: "square.grid.3x3.fill")
                }

            InsightsView()
                .tabItem {
                    Label("Reflect", systemImage: "sparkles")
                }

            SettingsView()
                .tabItem {
                    Label("You", systemImage: "person.crop.circle")
                }
        }
    }
}
