import SwiftData
import SwiftUI

@main
struct Muslim5App: App {
    private let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: PrayerRecord.self, TrackingPause.self)
        } catch {
            fatalError("Unable to create the local data store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .tint(AppTheme.accent)
        }
        .modelContainer(modelContainer)
    }
}
