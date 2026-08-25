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
}
