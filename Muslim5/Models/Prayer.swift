import Foundation

enum Prayer: String, CaseIterable, Codable, Identifiable {
    case fajr
    case dhuhr
    case asr
    case maghrib
    case isha

    var id: String { rawValue }

    var name: String {
        switch self {
        case .fajr: "Fajr"
        case .dhuhr: "Dhuhr"
        case .asr: "Asr"
        case .maghrib: "Maghrib"
        case .isha: "Isha"
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
        case .fajr: "It’s okay — begin again with Dhuhr"
        case .dhuhr: "It’s okay — Asr is a fresh chance"
        case .asr: "It’s okay — return with Maghrib"
        case .maghrib: "It’s okay — Isha is another chance"
        case .isha: "It’s okay — tomorrow begins with Fajr"
        }
    }

    var missedReflection: (title: String, body: String) {
        switch self {
        case .fajr:
            (
                "Fajr does not define the whole day",
                "If Fajr was missed, be gentle with yourself. Return with the next salah."
            )
        case .dhuhr:
            (
                "There is still room after Dhuhr",
                "If Dhuhr was missed, pause without despair and begin again with the next salah."
            )
        case .asr:
            (
                "The day can turn again after Asr",
                "If Asr was missed, carry a renewed intention into the prayer ahead."
            )
        case .maghrib:
            (
                "The evening still holds another chance",
                "If Maghrib was missed, meet the next salah with a gentle heart."
            )
        case .isha:
            (
                "Tomorrow opens again with Fajr",
                "If Isha was missed, rest without despair and begin again tomorrow."
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
        case .completed: "Completed"
        case .late: "Completed late"
        case .madeUp: "Prayed after time"
        }
    }

    var shortTitle: String {
        switch self {
        case .completed: "Done"
        case .late: "Late"
        case .madeUp: "After time"
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
        case .congregation: "Jamā'ah"
        case .individual: "Individual"
        }
    }

    var shortTitle: String {
        switch self {
        case .congregation: "Jamā'ah"
        case .individual: "Individual"
        }
    }

    var symbol: String {
        switch self {
        case .congregation: "person.3.fill"
        case .individual: "person.fill"
        }
    }
}
