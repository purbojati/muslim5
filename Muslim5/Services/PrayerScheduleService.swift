import Adhan
import CoreLocation
import Foundation

struct PrayerScheduleService {
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

        return DailyPrayerSchedule(
            fajr: times.fajr,
            sunrise: times.sunrise,
            dhuhr: times.dhuhr,
            asr: times.asr,
            maghrib: times.maghrib,
            isha: times.isha
        )
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
