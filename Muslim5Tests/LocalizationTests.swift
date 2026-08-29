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
