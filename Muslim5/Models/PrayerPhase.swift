import Foundation

enum PrayerScene: String, Equatable {
    case dawn
    case daylight
    case goldenHour
    case dusk
    case night
}

enum PrayerPhaseKind: Equatable {
    case active(Prayer)
    case upcoming(Prayer)
}

struct PrayerPhase: Equatable {
    let kind: PrayerPhaseKind
    let scene: PrayerScene
    let start: Date
    let end: Date

    var prayer: Prayer {
        switch kind {
        case .active(let prayer), .upcoming(let prayer): prayer
        }
    }

    var title: String {
        switch kind {
        case .active(let prayer): String(localized: "\(prayer.name) time")
        case .upcoming(let prayer): String(localized: "\(prayer.name) is next")
        }
    }

    var countdownVerb: String {
        switch kind {
        case .active: String(localized: "Ends")
        case .upcoming: String(localized: "Begins")
        }
    }

    var boundaryName: String {
        switch kind {
        case .upcoming(let prayer): prayer.name
        case .active(.fajr): String(localized: "Sunrise")
        case .active(.dhuhr): Prayer.asr.name
        case .active(.asr): Prayer.maghrib.name
        case .active(.maghrib): Prayer.isha.name
        case .active(.isha): Prayer.fajr.name
        }
    }

    func remaining(at date: Date) -> TimeInterval {
        max(0, end.timeIntervalSince(date))
    }

    func progress(at date: Date) -> Double {
        let duration = end.timeIntervalSince(start)
        guard duration > 0 else { return 0 }
        return min(max(date.timeIntervalSince(start) / duration, 0), 1)
    }

    func countdownText(at date: Date) -> String {
        let totalMinutes = max(1, Int(ceil(remaining(at: date) / 60)))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours == 0 {
            return String(localized: "\(countdownVerb) in \(minutes) min")
        } else if minutes == 0 {
            return String(localized: "\(countdownVerb) in \(hours) hr")
        } else {
            return String(localized: "\(countdownVerb) in \(hours) hr \(minutes) min")
        }
    }

    func accessibilityCountdownText(at date: Date) -> String {
        let totalMinutes = max(1, Int(ceil(remaining(at: date) / 60)))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        var parts: [String] = []

        if hours > 0 {
            parts.append(hours == 1
                ? String(localized: "1 hour")
                : String(localized: "\(hours) hours"))
        }
        if minutes > 0 {
            parts.append(minutes == 1
                ? String(localized: "1 minute")
                : String(localized: "\(minutes) minutes"))
        }

        let duration = parts.joined(separator: String(localized: " and "))
        return String(localized: "\(countdownVerb) in \(duration)")
    }
}

struct DailyPrayerSchedule: Equatable {
    let fajr: Date
    let sunrise: Date
    let dhuhr: Date
    let asr: Date
    let maghrib: Date
    let isha: Date

    func time(for prayer: Prayer) -> Date {
        switch prayer {
        case .fajr: fajr
        case .dhuhr: dhuhr
        case .asr: asr
        case .maghrib: maghrib
        case .isha: isha
        }
    }

    func endTime(for prayer: Prayer) -> Date? {
        switch prayer {
        case .fajr: sunrise
        case .dhuhr: asr
        case .asr: maghrib
        case .maghrib: isha
        case .isha: nil
        }
    }
}

struct PrayerSchedule: Equatable {
    let previous: DailyPrayerSchedule
    let today: DailyPrayerSchedule
    let tomorrow: DailyPrayerSchedule

    func endTime(for prayer: Prayer) -> Date {
        today.endTime(for: prayer) ?? tomorrow.fajr
    }

    func hasEnded(_ prayer: Prayer, at date: Date) -> Bool {
        date >= endTime(for: prayer)
    }

    func phase(at date: Date) -> PrayerPhase {
        if date < today.fajr {
            return PrayerPhase(
                kind: .active(.isha),
                scene: today.fajr.timeIntervalSince(date) <= 90 * 60 ? .dawn : .night,
                start: previous.isha,
                end: today.fajr
            )
        }

        if date < today.sunrise {
            return PrayerPhase(kind: .active(.fajr), scene: .dawn, start: today.fajr, end: today.sunrise)
        }

        if date < today.dhuhr {
            return PrayerPhase(kind: .upcoming(.dhuhr), scene: .daylight, start: today.sunrise, end: today.dhuhr)
        }

        if date < today.asr {
            return PrayerPhase(kind: .active(.dhuhr), scene: .daylight, start: today.dhuhr, end: today.asr)
        }

        if date < today.maghrib {
            return PrayerPhase(kind: .active(.asr), scene: .goldenHour, start: today.asr, end: today.maghrib)
        }

        if date < today.isha {
            return PrayerPhase(kind: .active(.maghrib), scene: .dusk, start: today.maghrib, end: today.isha)
        }

        return PrayerPhase(kind: .active(.isha), scene: .night, start: today.isha, end: tomorrow.fajr)
    }
}
