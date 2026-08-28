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
    var selection = FamilyActivitySelection()
    var activeRequirement: SalahFocusRequirement?
    var scheduledRequirement: SalahFocusRequirement?
    var completedRecordIdentifiers: Set<String> = []
    var pausedDayIdentifiers: Set<String> = []
    var revision = 0

    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty
    }

    var selectionCount: Int {
        selection.applicationTokens.count
            + selection.categoryTokens.count
            + selection.webDomainTokens.count
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
        "Salah Focus shared storage is unavailable. Check the App Group entitlement."
    }
}

enum SalahFocusShieldStore {
    static func apply(_ selection: FamilyActivitySelection) {
        let store = ManagedSettingsStore(named: SalahFocusConstants.storeName)

        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil
            : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty
            ? nil
            : selection.webDomainTokens
        store.shield.webDomainCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
    }

    static func clear() {
        ManagedSettingsStore(named: SalahFocusConstants.storeName).clearAllSettings()
    }
}
