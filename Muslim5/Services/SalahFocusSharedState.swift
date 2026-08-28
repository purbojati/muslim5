import FamilyControls
import Foundation
import ManagedSettings

enum SalahFocusConstants {
    static let appGroupIdentifier = "group.com.muslim5.app"
    static let activityPrefix = "muslim5.salah-focus"
    static let sharedStateKey = "salahFocus.sharedState"
    static var storeName: ManagedSettingsStore.Name {
        ManagedSettingsStore.Name("salah-focus")
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
        case "fajr": "Fajr"
        case "dhuhr": "Dhuhr"
        case "asr": "Asr"
        case "maghrib": "Maghrib"
        case "isha": "Isha"
        default: "salah"
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
    var completedRecordIdentifiers: Set<String> = []
    var pausedDayIdentifiers: Set<String> = []
    var revision = 0
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
        "Salah Focus shared storage is unavailable. Check the App Group entitlement."
    }
}

enum SalahFocusShieldStore {
    static func apply() {
        ManagedSettingsStore(named: SalahFocusConstants.storeName).clearAllSettings()
        let store = ManagedSettingsStore()
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
