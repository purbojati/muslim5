import Foundation
import SwiftData

@Model
final class PrayerRecord {
    @Attribute(.unique) var id: String
    var day: Date
    var prayerRawValue: String
    var statusRawValue: String
    var attendanceRawValue: String?
    var recordedAt: Date

    init(
        day: Date,
        prayer: Prayer,
        status: PrayerStatus,
        attendance: PrayerAttendance? = nil,
        calendar: Calendar = .current
    ) {
        let normalizedDay = calendar.startOfDay(for: day)
        self.id = PrayerRecord.identifier(for: normalizedDay, prayer: prayer, calendar: calendar)
        self.day = normalizedDay
        self.prayerRawValue = prayer.rawValue
        self.statusRawValue = status.rawValue
        self.attendanceRawValue = attendance?.rawValue
        self.recordedAt = .now
    }

    var prayer: Prayer {
        get { Prayer(rawValue: prayerRawValue) ?? .fajr }
        set { prayerRawValue = newValue.rawValue }
    }

    var status: PrayerStatus {
        get { PrayerStatus(rawValue: statusRawValue) ?? .completed }
        set { statusRawValue = newValue.rawValue }
    }

    var attendance: PrayerAttendance? {
        get { attendanceRawValue.flatMap(PrayerAttendance.init(rawValue:)) }
        set { attendanceRawValue = newValue?.rawValue }
    }

    static func identifier(for day: Date, prayer: Prayer, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)-\(prayer.rawValue)"
    }
}
