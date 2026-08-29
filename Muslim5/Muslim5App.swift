import SwiftData
import SwiftUI
import UIKit

@main
struct Muslim5App: App {
    @StateObject private var dataStore = Muslim5DataStore()

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
            if let modelContainer = dataStore.modelContainer {
                AppLaunchView()
                    .tint(AppTheme.accent)
                    .modelContainer(modelContainer)
            } else {
                DataStoreUnavailableView(
                    message: dataStore.errorMessage,
                    retry: dataStore.open
                )
                .tint(AppTheme.accent)
            }
        }
    }

    private static func serifFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let systemFont = UIFont.systemFont(ofSize: size, weight: weight)
        guard let serifDescriptor = systemFont.fontDescriptor.withDesign(.serif) else {
            return systemFont
        }

        return UIFont(descriptor: serifDescriptor, size: size)
    }
}

@MainActor
private final class Muslim5DataStore: ObservableObject {
    @Published private(set) var modelContainer: ModelContainer?
    @Published private(set) var errorMessage: String?

    init() {
        open()
    }

    func open() {
        do {
            let configuration = ModelConfiguration(
                schema: Muslim5Store.schema,
                cloudKitDatabase: Self.cloudKitDatabase
            )
            modelContainer = try ModelContainer(
                for: Muslim5Store.schema,
                migrationPlan: Muslim5MigrationPlan.self,
                configurations: [configuration]
            )
            errorMessage = nil
        } catch {
            modelContainer = nil
            errorMessage = error.localizedDescription
        }
    }

    private static var cloudKitDatabase: ModelConfiguration.CloudKitDatabase {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return .none
        }
        return .private(Muslim5Store.iCloudContainerIdentifier)
    }
}

private struct DataStoreUnavailableView: View {
    let message: String?
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Prayer history unavailable", systemImage: "exclamationmark.icloud.fill")
        } description: {
            Text("Muslim 5 could not open your prayer history. Your data was not replaced or deleted.")
            if let message {
                Text(message)
                    .font(.caption)
            }
        } actions: {
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
