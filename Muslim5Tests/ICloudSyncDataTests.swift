import SwiftData
import XCTest
@testable import Muslim_5

@MainActor
final class ICloudSyncDataTests: XCTestCase {
    func testPrayerUpsertKeepsOneLogicalRecord() throws {
        let context = try makeContext()
        let day = Date(timeIntervalSince1970: 1_700_000_000)

        try PrayerRecord.upsert(
            in: context,
            day: day,
            prayer: .fajr,
            status: .completed
        )
        try PrayerRecord.upsert(
            in: context,
            day: day,
            prayer: .fajr,
            status: .late,
            attendance: .congregation,
            updateAttendance: true
        )
        try context.save()

        let records = try context.fetch(FetchDescriptor<PrayerRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.status, .late)
        XCTAssertEqual(records.first?.attendance, .congregation)
    }

    func testNormalizerKeepsNewestPrayerAndRecoversAttendance() throws {
        let context = try makeContext()
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let older = PrayerRecord(
            day: day,
            prayer: .dhuhr,
            status: .completed,
            attendance: .congregation
        )
        older.recordedAt = Date(timeIntervalSince1970: 100)
        let newer = PrayerRecord(day: day, prayer: .dhuhr, status: .late)
        newer.recordedAt = Date(timeIntervalSince1970: 200)
        context.insert(older)
        context.insert(newer)
        try context.save()

        XCTAssertTrue(
            ICloudSyncDataNormalizer.normalize(
                records: [older, newer],
                pauses: [],
                in: context
            )
        )
        try context.save()

        let records = try context.fetch(FetchDescriptor<PrayerRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.status, .late)
        XCTAssertEqual(records.first?.attendance, .congregation)
    }

    func testNormalizerMergesOverlappingPeriodRanges() throws {
        let context = try makeContext()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let firstDay = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!
        let secondDay = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3))!
        let lastDay = calendar.date(from: DateComponents(year: 2026, month: 8, day: 5))!
        let first = TrackingPause(startDay: firstDay, endDay: secondDay, calendar: calendar)
        let second = TrackingPause(startDay: secondDay, endDay: lastDay, calendar: calendar)
        context.insert(first)
        context.insert(second)
        try context.save()

        XCTAssertTrue(
            ICloudSyncDataNormalizer.normalize(
                records: [],
                pauses: [first, second],
                in: context,
                calendar: calendar
            )
        )
        try context.save()

        let pauses = try context.fetch(FetchDescriptor<TrackingPause>())
        XCTAssertEqual(pauses.count, 1)
        XCTAssertEqual(pauses.first?.startDay, firstDay)
        XCTAssertEqual(pauses.first?.endDay, lastDay)
    }

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(
            schema: Muslim5Store.schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: Muslim5Store.schema,
            migrationPlan: Muslim5MigrationPlan.self,
            configurations: [configuration]
        )
        return ModelContext(container)
    }
}
