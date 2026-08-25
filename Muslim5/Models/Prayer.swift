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
