import Foundation

struct ProgressMetrics {
    let records: [PrayerRecord]
    let pauses: [TrackingPause]
    let calendar: Calendar

    init(records: [PrayerRecord], pauses: [TrackingPause] = [], calendar: Calendar = .current) {
        self.records = records
        self.pauses = pauses
        self.calendar = calendar
    }

    var recordsByDay: [Date: [PrayerRecord]] {
        Dictionary(grouping: records) { calendar.startOfDay(for: $0.day) }
    }

    func completedCount(on date: Date) -> Int {
        let day = calendar.startOfDay(for: date)
        return Set(recordsByDay[day, default: []].map(\.prayerRawValue)).count
    }

    func record(for prayer: Prayer, on date: Date) -> PrayerRecord? {
        let day = calendar.startOfDay(for: date)
        return recordsByDay[day]?.first { $0.prayer == prayer }
    }

    func isPaused(on date: Date) -> Bool {
        pauses.contains { $0.includes(date, calendar: calendar) }
    }

    var currentStreak: Int {
        var cursor = calendar.startOfDay(for: .now)
        while isPaused(on: cursor) {
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = previousDay
        }
        if completedCount(on: cursor) < Prayer.allCases.count {
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = previousDay
        }

        var streak = 0
        while true {
            if isPaused(on: cursor) {
                // Respectful pauses are neutral: they neither add to nor break a streak.
            } else if completedCount(on: cursor) == Prayer.allCases.count {
                streak += 1
            } else {
                break
            }
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }
        return streak
    }

    var perfectDays: Int {
        recordsByDay.values.filter { Set($0.map(\.prayerRawValue)).count == Prayer.allCases.count }.count
    }

    var last30DayConsistency: Double {
        let today = calendar.startOfDay(for: .now)
        let validDays = (0..<30)
            .compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
            .filter { !isPaused(on: $0) }
        guard !validDays.isEmpty else { return 0 }
        let total = validDays.reduce(0) { $0 + completedCount(on: $1) }
        return Double(total) / Double(validDays.count * Prayer.allCases.count)
    }

    var strongestPrayer: Prayer? {
        let counts = Dictionary(grouping: records, by: \.prayerRawValue).mapValues(\.count)
        return Prayer.allCases.max { counts[$0.rawValue, default: 0] < counts[$1.rawValue, default: 0] }
    }
}
