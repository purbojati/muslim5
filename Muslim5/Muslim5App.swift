import SwiftData
import SwiftUI
import UIKit

@main
struct Muslim5App: App {
    private let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: PrayerRecord.self, TrackingPause.self)
        } catch {
            fatalError("Unable to create the local data store: \(error)")
        }
    }()

    init() {
        let navigationBar = UINavigationBar.appearance()
        navigationBar.largeTitleTextAttributes = [
            .font: Self.serifFont(size: 34, weight: .bold)
        ]
        navigationBar.titleTextAttributes = [
            .font: Self.serifFont(size: 17, weight: .semibold)
        ]
    }

    var body: some Scene {
        WindowGroup {
            AppLaunchView()
                .tint(AppTheme.accent)
        }
        .modelContainer(modelContainer)
    }

    private static func serifFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let systemFont = UIFont.systemFont(ofSize: size, weight: weight)
        guard let serifDescriptor = systemFont.fontDescriptor.withDesign(.serif) else {
            return systemFont
        }

        return UIFont(descriptor: serifDescriptor, size: size)
    }
}
