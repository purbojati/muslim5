import CloudKit
import Foundation

@MainActor
final class ICloudStatusService: ObservableObject {
    enum Status: Equatable {
        case checking
        case available
        case noAccount
        case restricted
        case temporarilyUnavailable

        var label: String {
            switch self {
            case .checking:
                return "Checking…"
            case .available:
                return "Available"
            case .noAccount:
                return "Sign in to iCloud"
            case .restricted:
                return "Restricted"
            case .temporarilyUnavailable:
                return "Temporarily unavailable"
            }
        }

        var symbol: String {
            switch self {
            case .checking:
                return "icloud"
            case .available:
                return "checkmark.icloud.fill"
            case .noAccount:
                return "person.crop.circle.badge.exclamationmark"
            case .restricted, .temporarilyUnavailable:
                return "exclamationmark.icloud.fill"
            }
        }
    }

    @Published private(set) var status: Status = .checking

    private let containerIdentifier: String

    init(containerIdentifier: String = Muslim5Store.iCloudContainerIdentifier) {
        self.containerIdentifier = containerIdentifier
    }

    func refresh() async {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            status = .temporarilyUnavailable
            return
        }

        do {
            let container = CKContainer(identifier: containerIdentifier)
            switch try await container.accountStatus() {
            case .available:
                status = .available
            case .noAccount:
                status = .noAccount
            case .restricted:
                status = .restricted
            case .couldNotDetermine, .temporarilyUnavailable:
                status = .temporarilyUnavailable
            @unknown default:
                status = .temporarilyUnavailable
            }
        } catch {
            status = .temporarilyUnavailable
        }
    }
}
