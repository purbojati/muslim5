import Adhan
import CoreLocation
import Foundation

final class PrayerScheduleService: @unchecked Sendable {
    private struct DayCacheKey: Hashable {
        let latitude: Double
        let longitude: Double
        let year: Int
        let month: Int
        let day: Int
        let timeZoneIdentifier: String
        let calculationMethod: String
        let asrMethod: String
    }

    private let cacheLock = NSLock()
    private var dayCache: [DayCacheKey: DailyPrayerSchedule] = [:]

    func focusOccurrences(
        from schedule: PrayerSchedule,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [SalahFocusOccurrence] {
        [schedule.previous, schedule.today, schedule.tomorrow]
            .flatMap { day in
                Prayer.allCases.map { prayer in
                    let start = day.time(for: prayer)
                    return SalahFocusOccurrence(
                        prayer: prayer,
                        day: calendar.startOfDay(for: start),
                        start: start
                    )
                }
            }
            .sorted { $0.start < $1.start }
    }

    func dailySchedule(
        for coordinate: CLLocationCoordinate2D,
        at date: Date,
        timeZone: TimeZone = .autoupdatingCurrent,
        calculationMethod: String,
        asrMethod: String
    ) -> DailyPrayerSchedule? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        return makeDay(
            for: coordinate,
            date: date,
            calendar: calendar,
            calculationMethod: calculationMethod,
            asrMethod: asrMethod
        )
    }

    func schedule(
        for coordinate: CLLocationCoordinate2D,
        at date: Date,
        timeZone: TimeZone = .autoupdatingCurrent,
        calculationMethod: String,
        asrMethod: String
    ) -> PrayerSchedule? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        guard
            let previousDate = calendar.date(byAdding: .day, value: -1, to: date),
            let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: date),
            let previous = makeDay(
                for: coordinate,
                date: previousDate,
                calendar: calendar,
                calculationMethod: calculationMethod,
                asrMethod: asrMethod
            ),
            let today = makeDay(
                for: coordinate,
                date: date,
                calendar: calendar,
                calculationMethod: calculationMethod,
                asrMethod: asrMethod
            ),
            let tomorrow = makeDay(
                for: coordinate,
                date: tomorrowDate,
                calendar: calendar,
                calculationMethod: calculationMethod,
                asrMethod: asrMethod
            )
        else {
            return nil
        }

        return PrayerSchedule(previous: previous, today: today, tomorrow: tomorrow)
    }

    private func makeDay(
        for coordinate: CLLocationCoordinate2D,
        date: Date,
        calendar: Calendar,
        calculationMethod: String,
        asrMethod: String
    ) -> DailyPrayerSchedule? {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let cacheKey = DayCacheKey(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            year: components.year ?? 0,
            month: components.month ?? 0,
            day: components.day ?? 0,
            timeZoneIdentifier: calendar.timeZone.identifier,
            calculationMethod: calculationMethod,
            asrMethod: asrMethod
        )
        if let cached = cachedDay(for: cacheKey) {
            return cached
        }

        let coordinates = Adhan.Coordinates(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var parameters = parameters(for: calculationMethod)
        parameters.madhab = asrMethod == "hanafi" ? .hanafi : .shafi

        guard let times = Adhan.PrayerTimes(
            coordinates: coordinates,
            date: components,
            calculationParameters: parameters
        ) else {
            return nil
        }

        let schedule = DailyPrayerSchedule(
            fajr: times.fajr,
            sunrise: times.sunrise,
            dhuhr: times.dhuhr,
            asr: times.asr,
            maghrib: times.maghrib,
            isha: times.isha
        )
        cache(schedule, for: cacheKey)
        return schedule
    }

    private func cachedDay(for key: DayCacheKey) -> DailyPrayerSchedule? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return dayCache[key]
    }

    private func cache(_ schedule: DailyPrayerSchedule, for key: DayCacheKey) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if dayCache.count >= 64 {
            dayCache.removeAll(keepingCapacity: true)
        }
        dayCache[key] = schedule
    }

    private func parameters(for method: String) -> CalculationParameters {
        switch method {
        case "mwl": CalculationMethod.muslimWorldLeague.params
        case "ummAlQura": CalculationMethod.ummAlQura.params
        case "muis": CalculationMethod.singapore.params
        default: CalculationMethod.singapore.params
        }
    }
}
