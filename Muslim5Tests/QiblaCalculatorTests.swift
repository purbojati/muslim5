import CoreLocation
import XCTest
@testable import Muslim_5

final class QiblaCalculatorTests: XCTestCase {
    func testBearingFromJakarta() {
        let jakarta = CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
        XCTAssertEqual(QiblaCalculator.bearing(from: jakarta), 295.15, accuracy: 0.01)
    }

    func testBearingFromLondon() {
        let london = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        XCTAssertEqual(QiblaCalculator.bearing(from: london), 118.99, accuracy: 0.01)
    }

    func testBearingFromNewYork() {
        let newYork = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        XCTAssertEqual(QiblaCalculator.bearing(from: newYork), 58.48, accuracy: 0.01)
    }

    func testBearingAcrossLongitudeWraparound() {
        let origin = CLLocationCoordinate2D(latitude: 0, longitude: 179)
        let destination = CLLocationCoordinate2D(latitude: 0, longitude: -179)
        XCTAssertEqual(
            QiblaCalculator.bearing(from: origin, to: destination),
            90,
            accuracy: 0.001
        )
    }

    func testSignedTurnUsesShortestDirectionAcrossNorth() {
        XCTAssertEqual(QiblaCalculator.signedTurn(from: 350, to: 10), 20, accuracy: 0.001)
        XCTAssertEqual(QiblaCalculator.signedTurn(from: 10, to: 350), -20, accuracy: 0.001)
    }

    func testNormalizeKeepsAnglesWithinCompassRange() {
        XCTAssertEqual(QiblaCalculator.normalize(370), 10, accuracy: 0.001)
        XCTAssertEqual(QiblaCalculator.normalize(-10), 350, accuracy: 0.001)
    }
}

final class PrayerScheduleTests: XCTestCase {
    private let day = DailyPrayerSchedule(
        fajr: Date(timeIntervalSince1970: 100),
        sunrise: Date(timeIntervalSince1970: 200),
        dhuhr: Date(timeIntervalSince1970: 300),
        asr: Date(timeIntervalSince1970: 400),
        maghrib: Date(timeIntervalSince1970: 500),
        isha: Date(timeIntervalSince1970: 600)
    )

    private var schedule: PrayerSchedule {
        PrayerSchedule(
            previous: day,
            today: day,
            tomorrow: DailyPrayerSchedule(
                fajr: Date(timeIntervalSince1970: 700),
                sunrise: Date(timeIntervalSince1970: 800),
                dhuhr: Date(timeIntervalSince1970: 900),
                asr: Date(timeIntervalSince1970: 1_000),
                maghrib: Date(timeIntervalSince1970: 1_100),
                isha: Date(timeIntervalSince1970: 1_200)
            )
        )
    }

    func testEachPrayerWindowEndsAtTheNextRelevantBoundary() {
        XCTAssertEqual(schedule.endTime(for: .fajr), Date(timeIntervalSince1970: 200))
        XCTAssertEqual(schedule.endTime(for: .dhuhr), Date(timeIntervalSince1970: 400))
        XCTAssertEqual(schedule.endTime(for: .asr), Date(timeIntervalSince1970: 500))
        XCTAssertEqual(schedule.endTime(for: .maghrib), Date(timeIntervalSince1970: 600))
        XCTAssertEqual(schedule.endTime(for: .isha), Date(timeIntervalSince1970: 700))
    }

    func testPrayerWindowChangesToEndedAtItsBoundary() {
        XCTAssertFalse(schedule.hasEnded(.dhuhr, at: Date(timeIntervalSince1970: 399)))
        XCTAssertTrue(schedule.hasEnded(.dhuhr, at: Date(timeIntervalSince1970: 400)))
    }

    func testEveryPrayerHasDistinctPassedTimeEncouragement() {
        let messages = Set(Prayer.allCases.map(\.passedTimeEncouragement))

        XCTAssertEqual(messages.count, Prayer.allCases.count)
        XCTAssertTrue(messages.allSatisfy { $0.hasPrefix("It’s okay") })
    }

    func testEveryPrayerHasDistinctMissedReflection() {
        let titles = Set(Prayer.allCases.map { $0.missedReflection.title })
        let bodies = Set(Prayer.allCases.map { $0.missedReflection.body })

        XCTAssertEqual(titles.count, Prayer.allCases.count)
        XCTAssertEqual(bodies.count, Prayer.allCases.count)
        for prayer in Prayer.allCases {
            XCTAssertTrue(prayer.missedReflection.body.contains(prayer.name))
        }
    }
}
