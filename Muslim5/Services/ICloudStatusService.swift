import CloudKit
import Combine
import CoreData
import Foundation

struct ICloudSyncStateMachine: Equatable {
    enum State: Equatable {
        case checking
        case ready
        case waitingToBackUp
        case syncing
        case upToDate(Date)
        case backedUp(Date)
        case failed(String)
        case unavailable

        var label: String {
            switch self {
            case .checking:
                return String(localized: "Checking…")
            case .ready:
                return String(localized: "Ready")
            case .waitingToBackUp:
                return String(localized: "Waiting to back up")
            case .syncing:
                return String(localized: "Syncing…")
            case .upToDate:
                return String(localized: "Up to date")
            case .backedUp:
                return String(localized: "Backed up")
            case .failed:
                return String(localized: "Sync failed")
            case .unavailable:
                return String(localized: "Unavailable")
            }
        }

        var detail: String? {
            switch self {
            case .waitingToBackUp:
                return String(localized: "Keep Muslim 5 open and connected until the backup finishes.")
            case .syncing:
                return String(localized: "Sending prayer data securely to iCloud.")
            case let .upToDate(date):
                return String(localized: "Last checked \(date.formatted(date: .omitted, time: .shortened)).")
            case let .backedUp(date):
                return String(localized: "Last confirmed \(date.formatted(date: .omitted, time: .shortened)).")
            case let .failed(message):
                return message
            case .checking, .ready, .unavailable:
                return nil
            }
        }
    }

    enum EventKind: Equatable {
        case setup
        case `import`
        case export
    }

    private(set) var state: State = .checking
    private(set) var hasPendingLocalChanges = false

    mutating func accountBecameAvailable() {
        guard !hasPendingLocalChanges else { return }
        if state == .checking || state == .unavailable {
            state = .ready
        }
    }

    mutating func accountBecameUnavailable() {
        state = .unavailable
    }

    mutating func localChangeSaved() {
        hasPendingLocalChanges = true
        state = .waitingToBackUp
    }

    mutating func eventStarted(_ kind: EventKind) {
        guard kind == .export || !hasPendingLocalChanges else { return }
        state = .syncing
    }

    mutating func eventFinished(
        _ kind: EventKind,
        succeeded: Bool,
        at date: Date,
        errorMessage: String? = nil
    ) {
        guard succeeded else {
            state = .failed(errorMessage ?? String(localized: "iCloud could not finish syncing. Try again while online."))
            return
        }

        switch kind {
        case .export:
            hasPendingLocalChanges = false
            state = .backedUp(date)
        case .setup, .import:
            guard !hasPendingLocalChanges else { return }
            state = .upToDate(date)
        }
    }
}

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
                return String(localized: "Checking…")
            case .available:
                return String(localized: "Available")
            case .noAccount:
                return String(localized: "Sign in to iCloud")
            case .restricted:
                return String(localized: "Restricted")
            case .temporarilyUnavailable:
                return String(localized: "Temporarily unavailable")
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
    @Published private(set) var syncStatus = ICloudSyncStateMachine.State.checking

    private let containerIdentifier: String
    private var stateMachine = ICloudSyncStateMachine()
    private var eventSubscription: AnyCancellable?

    init(containerIdentifier: String = Muslim5Store.iCloudContainerIdentifier) {
        self.containerIdentifier = containerIdentifier
        eventSubscription = NotificationCenter.default
            .publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.consumeCloudKitEvent(notification)
            }
    }

    func refresh() async {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            status = .temporarilyUnavailable
            stateMachine.accountBecameUnavailable()
            publishSyncStatus()
            return
        }

        do {
            let container = CKContainer(identifier: containerIdentifier)
            switch try await container.accountStatus() {
            case .available:
                status = .available
                stateMachine.accountBecameAvailable()
            case .noAccount:
                status = .noAccount
                stateMachine.accountBecameUnavailable()
            case .restricted:
                status = .restricted
                stateMachine.accountBecameUnavailable()
            case .couldNotDetermine, .temporarilyUnavailable:
                status = .temporarilyUnavailable
                stateMachine.accountBecameUnavailable()
            @unknown default:
                status = .temporarilyUnavailable
                stateMachine.accountBecameUnavailable()
            }
        } catch {
            status = .temporarilyUnavailable
            stateMachine.accountBecameUnavailable()
        }
        publishSyncStatus()
    }

    func markLocalChangePending() {
        stateMachine.localChangeSaved()
        publishSyncStatus()
    }

    private func consumeCloudKitEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[
            NSPersistentCloudKitContainer.eventNotificationUserInfoKey
        ] as? NSPersistentCloudKitContainer.Event,
        let kind = eventKind(for: event.type) else { return }

        if let endDate = event.endDate {
            stateMachine.eventFinished(
                kind,
                succeeded: event.succeeded,
                at: endDate,
                errorMessage: event.error?.localizedDescription
            )
        } else {
            stateMachine.eventStarted(kind)
        }
        publishSyncStatus()
    }

    private func eventKind(
        for type: NSPersistentCloudKitContainer.EventType
    ) -> ICloudSyncStateMachine.EventKind? {
        switch type {
        case .setup:
            return .setup
        case .import:
            return .import
        case .export:
            return .export
        @unknown default:
            return nil
        }
    }

    private func publishSyncStatus() {
        syncStatus = stateMachine.state
    }
}
