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
