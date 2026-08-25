import Foundation
import XCTest
@testable import Muslim_5

final class SharingServiceTests: XCTestCase {
    func testSharingUserInitialUsesFirstVisibleNicknameCharacter() {
        let user = SharingUser(
            id: "user-1",
            nickname: "  aisha ",
            avatar: "unused"
        )

        XCTAssertEqual(user.initial, "A")
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
