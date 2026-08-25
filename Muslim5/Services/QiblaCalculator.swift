import CoreLocation
import Foundation

enum QiblaCalculator {
    static let kaabaCoordinate = CLLocationCoordinate2D(
        latitude: 21.4225,
        longitude: 39.8262
    )

    static func bearing(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D = kaabaCoordinate
    ) -> CLLocationDirection {
        let originLatitude = origin.latitude.degreesToRadians
        let destinationLatitude = destination.latitude.degreesToRadians
        let longitudeDifference = (destination.longitude - origin.longitude).degreesToRadians

        let y = sin(longitudeDifference) * cos(destinationLatitude)
        let x = cos(originLatitude) * sin(destinationLatitude)
            - sin(originLatitude) * cos(destinationLatitude) * cos(longitudeDifference)

        return normalize(atan2(y, x).radiansToDegrees)
    }

    static func signedTurn(
        from heading: CLLocationDirection,
        to bearing: CLLocationDirection
    ) -> CLLocationDirection {
        var difference = normalize(bearing) - normalize(heading)

        if difference > 180 {
            difference -= 360
        } else if difference <= -180 {
            difference += 360
        }

        return difference
    }

    static func normalize(_ degrees: CLLocationDirection) -> CLLocationDirection {
        let result = degrees.truncatingRemainder(dividingBy: 360)
        return result >= 0 ? result : result + 360
    }
}

private extension Double {
    var degreesToRadians: Double { self * .pi / 180 }
    var radiansToDegrees: Double { self * 180 / .pi }
}
