import SwiftUI

struct RootTabView: View {
    var body: some View {
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
