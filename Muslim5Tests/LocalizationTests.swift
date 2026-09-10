import Foundation
import XCTest
@testable import Muslim_5

final class LocalizationTests: XCTestCase {
    private let indonesian = Locale(identifier: "id")

    private var indonesianBundle: Bundle {
        get throws {
            let path = try XCTUnwrap(Bundle.main.path(forResource: "id", ofType: "lproj"))
            return try XCTUnwrap(Bundle(path: path))
        }
    }

    func testIndonesianPrayerNamesUseLocalTerms() throws {
        let bundle = try indonesianBundle
        let names = Prayer.allCases.map {
            $0.localizedName(locale: indonesian, bundle: bundle)
        }

        XCTAssertEqual(names, ["Subuh", "Zuhur", "Asar", "Magrib", "Isya"])
    }

    func testLocalizationDoesNotChangeStoredPrayerIdentifiers() {
        XCTAssertEqual(
            Prayer.allCases.map(\.rawValue),
            ["fajr", "dhuhr", "asr", "maghrib", "isha"]
        )
    }

    @MainActor
    func testIndonesianPrayerNotificationsAreContextual() throws {
        let bundle = try indonesianBundle
        XCTAssertEqual(
            PrayerNotificationService.notificationMessage(
                for: .fajr,
                locale: indonesian,
                bundle: bundle
            ).title,
            "🌅 Subuh — Awali bersama Allah"
        )
        XCTAssertEqual(
            PrayerNotificationService.notificationMessage(
                for: .dhuhr,
                locale: indonesian,
                bundle: bundle
            ).body,
            "Jeda sejenak dari kesibukan. Waktu Zuhur telah tiba."
        )
    }

    @MainActor
    func testDhuhrNotificationUsesJumuahCopyOnFriday() throws {
        let bundle = try indonesianBundle
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Jakarta"))
        let friday = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 12))
        )

        let message = PrayerNotificationService.notificationMessage(
            for: .dhuhr,
            at: friday,
            calendar: calendar,
            locale: indonesian,
            bundle: bundle
        )

        XCTAssertEqual(message.title, "🕌 Jumuah — Sambut panggilan-Nya")
        XCTAssertEqual(
            message.body,
            "Hari ini Jumat. Luangkan waktu untuk salat Jumat dan mengingat Allah."
        )
    }

    @MainActor
    func testDhuhrNotificationKeepsRegularCopyOutsideFriday() throws {
        let bundle = try indonesianBundle
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Jakarta"))
        let thursday = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 12))
        )

        let message = PrayerNotificationService.notificationMessage(
            for: .dhuhr,
            at: thursday,
            calendar: calendar,
            locale: indonesian,
            bundle: bundle
        )

        XCTAssertEqual(message.title, "☀️ Zuhur — Berhenti sejenak dan kembali")
    }

    @MainActor
    func testJumuahAtmosphereBeginsAtThursdayMaghrib() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Jakarta"))
        let maghrib = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 18))
        )
        let beforeMaghrib = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 17, minute: 59))
        )

        XCTAssertFalse(
            TodayView.isJumuahPeriod(beforeMaghrib, maghrib: maghrib, calendar: calendar)
        )
        XCTAssertTrue(
            TodayView.isJumuahPeriod(maghrib, maghrib: maghrib, calendar: calendar)
        )
    }

    @MainActor
    func testJumuahAtmosphereEndsAtFridayMaghrib() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Jakarta"))
        let maghrib = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 18))
        )
        let beforeMaghrib = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 17, minute: 59))
        )

        XCTAssertTrue(
            TodayView.isJumuahPeriod(beforeMaghrib, maghrib: maghrib, calendar: calendar)
        )
        XCTAssertFalse(
            TodayView.isJumuahPeriod(maghrib, maghrib: maghrib, calendar: calendar)
        )
    }

    func testEveryCatalogEntryHasAnApprovedIndonesianTranslation() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        try assertCompleteIndonesianCatalog(
            at: repositoryRoot.appending(path: "Muslim5/Localizable.xcstrings")
        )
        try assertCompleteIndonesianCatalog(
            at: repositoryRoot.appending(path: "SalahFocusShieldConfiguration/Localizable.xcstrings")
        )
    }

    private func assertCompleteIndonesianCatalog(at url: URL) throws {
        let data = try Data(contentsOf: url)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: Any])

        XCTAssertFalse(strings.isEmpty, "Expected localization entries in \(url.lastPathComponent)")

        for (key, rawEntry) in strings {
            let entry = try XCTUnwrap(rawEntry as? [String: Any])
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any])
            let indonesian = try XCTUnwrap(
                localizations["id"] as? [String: Any],
                "Missing Indonesian translation for \(key)"
            )
            let stringUnit = try XCTUnwrap(indonesian["stringUnit"] as? [String: Any])

            XCTAssertEqual(
                stringUnit["state"] as? String,
                "translated",
                "Indonesian translation is not approved for \(key)"
            )
            XCTAssertFalse(
                (stringUnit["value"] as? String)?.isEmpty ?? true,
                "Indonesian translation is empty for \(key)"
            )
        }
    }
}
