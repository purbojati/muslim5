import Foundation
import SwiftData

@Model
final class TrackingPause {
    var id: UUID
    var startDay: Date
    var endDay: Date?
    var reason: String

    init(startDay: Date = .now, endDay: Date? = nil, reason: String = "period", calendar: Calendar = .current) {
        self.id = UUID()
        self.startDay = calendar.startOfDay(for: startDay)
        self.endDay = endDay.map { calendar.startOfDay(for: $0) }
        self.reason = reason
    }

    func includes(_ date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        let lastDay = endDay.map { calendar.startOfDay(for: $0) } ?? .distantFuture
        return day >= calendar.startOfDay(for: startDay) && day <= lastDay
    }
}
