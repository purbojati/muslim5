import Foundation

enum Prayer: String, CaseIterable, Codable, Identifiable {
    case fajr
    case dhuhr
    case asr
    case maghrib
    case isha

    var id: String { rawValue }

    var name: String { localizedName() }

    func localizedName(
        locale: Locale = .autoupdatingCurrent,
        bundle: Bundle = .main
    ) -> String {
        switch self {
        case .fajr: String(localized: "Fajr", bundle: bundle, locale: locale)
        case .dhuhr: String(localized: "Dhuhr", bundle: bundle, locale: locale)
        case .asr: String(localized: "Asr", bundle: bundle, locale: locale)
        case .maghrib: String(localized: "Maghrib", bundle: bundle, locale: locale)
        case .isha: String(localized: "Isha", bundle: bundle, locale: locale)
        }
    }

    var symbol: String {
        switch self {
        case .fajr: "sunrise.fill"
        case .dhuhr: "sun.max.fill"
        case .asr: "sun.haze.fill"
        case .maghrib: "sunset.fill"
        case .isha: "moon.stars.fill"
        }
    }

    var passedTimeEncouragement: String {
        switch self {
        case .fajr: String(localized: "It’s okay — begin again with Dhuhr")
        case .dhuhr: String(localized: "It’s okay — Asr is a fresh chance")
        case .asr: String(localized: "It’s okay — return with Maghrib")
        case .maghrib: String(localized: "It’s okay — Isha is another chance")
        case .isha: String(localized: "It’s okay — tomorrow begins with Fajr")
        }
    }

    var missedReflection: (title: String, body: String) {
        switch self {
        case .fajr:
            (
                String(localized: "Fajr does not define the whole day"),
                String(localized: "If Fajr was missed, be gentle with yourself. Return with the next salah.")
            )
        case .dhuhr:
            (
                String(localized: "There is still room after Dhuhr"),
                String(localized: "If Dhuhr was missed, pause without despair and begin again with the next salah.")
            )
        case .asr:
            (
                String(localized: "The day can turn again after Asr"),
                String(localized: "If Asr was missed, carry a renewed intention into the prayer ahead.")
            )
        case .maghrib:
            (
                String(localized: "The evening still holds another chance"),
                String(localized: "If Maghrib was missed, meet the next salah with a gentle heart.")
            )
        case .isha:
            (
                String(localized: "Tomorrow opens again with Fajr"),
                String(localized: "If Isha was missed, rest without despair and begin again tomorrow.")
            )
        }
    }
}

enum PrayerStatus: String, CaseIterable, Codable {
    case completed
    case late
    case madeUp

    var title: String {
        switch self {
        case .completed: String(localized: "Completed")
        case .late: String(localized: "Completed late")
        case .madeUp: String(localized: "Prayed after time")
        }
    }

    var shortTitle: String {
        switch self {
        case .completed: String(localized: "Done")
        case .late: String(localized: "Late")
        case .madeUp: String(localized: "After time")
        }
    }

    var symbol: String {
        switch self {
        case .completed: "checkmark"
        case .late: "clock"
        case .madeUp: "arrow.counterclockwise"
        }
    }
}

enum PrayerAttendance: String, CaseIterable, Codable {
    case congregation
    case individual

    var title: String {
        switch self {
        case .congregation: String(localized: "Jamā'ah")
        case .individual: String(localized: "Individual")
        }
    }

    var shortTitle: String {
        switch self {
        case .congregation: String(localized: "Jamā'ah")
        case .individual: String(localized: "Individual")
        }
    }

    var symbol: String {
        switch self {
        case .congregation: "person.3.fill"
        case .individual: "person.fill"
        }
    }
}
