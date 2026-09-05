import FamilyControls
import Foundation
import ManagedSettings

enum SalahFocusConstants {
    static let appGroupIdentifier = "group.com.muslim5.app"
    static let activityPrefix = "muslim5.salah-focus"
    static let temporaryUnlockActivity = "\(activityPrefix).temporary-unlock"
    static let temporaryUnlockDuration: TimeInterval = 30 * 60
    static let monitoringWindowDayCount = 1
    static let sharedStateKey = "salahFocus.sharedState"
    static var storeName: ManagedSettingsStore.Name {
        ManagedSettingsStore.Name("salah-focus")
    }

    static func activityName(
        for requirement: SalahFocusRequirement,
        revision: Int
    ) -> String {
        "\(activityPrefix).\(revision).\(requirement.dayIdentifier).\(requirement.prayerRawValue)"
    }
}

struct SalahFocusRequirement: Codable, Equatable {
    let prayerRawValue: String
    let dayIdentifier: String
    let start: Date

    var recordIdentifier: String {
        "\(dayIdentifier)-\(prayerRawValue)"
    }

    var prayerName: String {
        switch prayerRawValue {
        case "fajr": String(localized: "Fajr")
        case "dhuhr": String(localized: "Dhuhr")
        case "asr": String(localized: "Asr")
        case "maghrib": String(localized: "Maghrib")
        case "isha": String(localized: "Isha")
        default: String(localized: "salah")
        }
    }
}

struct SalahFocusSharedState: Codable, Equatable {
    static let currentVersion = 1

    var version = currentVersion
    var isEnabled = false
    var enabledAt: Date?
    // Retained so existing version-1 state created by the app-picker build remains decodable.
    var selection = FamilyActivitySelection()
    var activeRequirement: SalahFocusRequirement?
    var scheduledRequirement: SalahFocusRequirement?
    var temporaryUnlockUntil: Date?
    var completedRecordIdentifiers: Set<String> = []
    var pausedDayIdentifiers: Set<String> = []
    var revision = 0
}

enum SalahFocusMonitorStartDecision: Equatable {
    case ignore
    case clear
    case shield(SalahFocusRequirement)

    static func resolve(
        activityName: String,
        state: SalahFocusSharedState
    ) -> SalahFocusMonitorStartDecision {
        guard state.isEnabled else {
            return .clear
        }

        guard
            let requirement = state.scheduledRequirement,
            activityName == SalahFocusConstants.activityName(
                for: requirement,
                revision: state.revision
            )
        else {
            // A stopped DeviceActivity can still deliver a delayed callback. It
            // must not clear a shield created by a newer state revision.
            return .ignore
        }

        guard
            !state.completedRecordIdentifiers.contains(requirement.recordIdentifier),
            !state.pausedDayIdentifiers.contains(requirement.dayIdentifier)
        else {
            return .clear
        }

        return .shield(requirement)
    }
}

enum SalahFocusSharedStorage {
    static func load() -> SalahFocusSharedState {
        guard
            let defaults = makeDefaults(),
            let data = defaults.data(forKey: SalahFocusConstants.sharedStateKey),
            let state = try? JSONDecoder().decode(SalahFocusSharedState.self, from: data),
            state.version == SalahFocusSharedState.currentVersion
        else {
            return SalahFocusSharedState()
        }
        return state
    }

    static func save(_ state: SalahFocusSharedState) throws {
        guard let defaults = makeDefaults() else {
            throw SalahFocusSharedStorageError.appGroupUnavailable
        }
        let data = try JSONEncoder().encode(state)
        defaults.set(data, forKey: SalahFocusConstants.sharedStateKey)
    }

    private static func makeDefaults() -> UserDefaults? {
        UserDefaults(suiteName: SalahFocusConstants.appGroupIdentifier)
    }
}

private enum SalahFocusSharedStorageError: LocalizedError {
    case appGroupUnavailable

    var errorDescription: String? {
        String(localized: "Salah Focus shared storage is unavailable. Check the App Group entitlement.")
    }
}

enum SalahFocusShieldStore {
    static func apply() {
        let store = ManagedSettingsStore(named: SalahFocusConstants.storeName)
        store.clearAllSettings()
        store.shield.applications = nil
        store.shield.applicationCategories = .all()
        store.shield.webDomains = nil
        store.shield.webDomainCategories = .all()
    }

    static func clear() {
        ManagedSettingsStore().clearAllSettings()
        ManagedSettingsStore(named: SalahFocusConstants.storeName).clearAllSettings()
    }
}
