import Foundation
import XCTest
@testable import Muslim_5

final class SharingServiceTests: XCTestCase {
    func testSharingUserInitialsUseTwoVisibleCharacters() {
        let fullName = SharingUser(
            id: "user-1",
            nickname: "  Adjie Purbojati ",
            avatar: "unused"
        )
        let singleName = SharingUser(
            id: "user-2",
            nickname: "Aisha",
            avatar: "unused"
        )

        XCTAssertEqual(fullName.initials, "AP")
        XCTAssertEqual(singleName.initials, "AI")
    }

    func testPrayerUsersDecodeAndMapByPrayer() throws {
        let data = Data(
            """
            {
              "fajr": [
                { "id": "user-1", "nickname": "Aisha", "avatar": "moon.stars.fill" }
              ],
              "dhuhr": [],
              "asr": [],
              "maghrib": [],
              "isha": [
                { "id": "user-2", "nickname": "Omar", "avatar": "star.fill" }
              ]
            }
            """.utf8
        )

        let decoded = try JSONDecoder().decode(SharingPrayerUsers.self, from: data)

        XCTAssertEqual(decoded.users(for: .fajr).map(\.nickname), ["Aisha"])
        XCTAssertEqual(decoded.users(for: .dhuhr), [])
        XCTAssertEqual(decoded.users(for: .isha).map(\.nickname), ["Omar"])
    }

    func testResponseCacheIsScopedByTokenAndLimitsPrayerHistory() throws {
        let suiteName = "SharingServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let cache = SharingResponseCache(defaults: defaults)
        let profile = SharingProfile(
            id: "user-1",
            nickname: "Aisha",
            avatar: "moon.stars.fill",
            linkCode: "ABCDE-FGHIJ",
            createdAt: "2026-09-01T00:00:00Z",
            updatedAt: "2026-09-01T00:00:00Z"
        )
        let emptyUsers = SharingPrayerUsers(
            fajr: [], dhuhr: [], asr: [], maghrib: [], isha: []
        )
        let days = Dictionary(uniqueKeysWithValues: (1...20).map {
            (String(format: "2026-09-%02d", $0), emptyUsers)
        })
        let snapshot = SharingCacheSnapshot(
            profile: profile,
            linkedUsers: [],
            prayerUsersByDate: days
        )

        cache.save(snapshot, for: "token-a")

        let restored = try XCTUnwrap(cache.load(for: "token-a"))
        XCTAssertEqual(restored.profile, profile)
        XCTAssertEqual(restored.prayerUsersByDate.count, 14)
        XCTAssertNil(cache.load(for: "token-b"))

        cache.remove(for: "token-a")
        XCTAssertNil(cache.load(for: "token-a"))
    }
}
