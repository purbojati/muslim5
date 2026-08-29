import Foundation
import SwiftData

@Model
final class PrayerRecord {
    var id: String = ""
    var day: Date = Date.distantPast
    var prayerRawValue: String = Prayer.fajr.rawValue
    var statusRawValue: String = PrayerStatus.completed.rawValue
    var attendanceRawValue: String?
    var recordedAt: Date = Date.distantPast

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

    @discardableResult
    static func upsert(
        in context: ModelContext,
        day: Date,
        prayer: Prayer,
        status: PrayerStatus? = nil,
        attendance: PrayerAttendance? = nil,
        updateAttendance: Bool = false,
        calendar: Calendar = .current
    ) throws -> PrayerRecord {
        let normalizedDay = calendar.startOfDay(for: day)
        let identifier = identifier(for: normalizedDay, prayer: prayer, calendar: calendar)
        let predicate = #Predicate<PrayerRecord> { record in
            record.id == identifier
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\PrayerRecord.recordedAt, order: .reverse)]
        let matches = try context.fetch(descriptor)

        let record: PrayerRecord
        if let existing = matches.first {
            record = existing
            if let status {
                record.status = status
            }
            if updateAttendance {
                record.attendance = attendance
            }
            record.recordedAt = .now
        } else {
            record = PrayerRecord(
                day: normalizedDay,
                prayer: prayer,
                status: status ?? .completed,
                attendance: updateAttendance ? attendance : nil,
                calendar: calendar
            )
            context.insert(record)
        }

        for duplicate in matches.dropFirst() {
            context.delete(duplicate)
        }
        return record
    }

    static func deleteAll(
        in context: ModelContext,
        day: Date,
        prayer: Prayer,
        calendar: Calendar = .current
    ) throws {
        let identifier = identifier(for: day, prayer: prayer, calendar: calendar)
        let predicate = #Predicate<PrayerRecord> { record in
            record.id == identifier
        }
        for record in try context.fetch(FetchDescriptor(predicate: predicate)) {
            context.delete(record)
        }
    }
}
