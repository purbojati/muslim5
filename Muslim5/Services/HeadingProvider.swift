import CoreLocation
import Foundation
import UIKit

@MainActor
final class HeadingProvider: NSObject, ObservableObject {
    enum State: Equatable {
        case idle
        case updating
        case unavailable
    }

    @Published private(set) var heading: CLLocationDirection?
    @Published private(set) var accuracy: CLLocationDirection?
    @Published private(set) var state: State = .idle

    private let manager = CLLocationManager()
    private var isActive = false

    override init() {
        super.init()
        manager.delegate = self
        manager.headingFilter = 1
    }

    func start() {
        guard CLLocationManager.headingAvailable() else {
            state = .unavailable
            return
        }

        guard !isActive else { return }
        isActive = true
        manager.headingOrientation = .portrait
        state = .updating
        manager.startUpdatingHeading()
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        manager.stopUpdatingHeading()
        state = .idle
    }

    private func publish(_ newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }

        let measuredHeading = newHeading.trueHeading >= 0
            ? newHeading.trueHeading
            : newHeading.magneticHeading

        if let heading {
            let change = QiblaCalculator.signedTurn(from: heading, to: measuredHeading)
            self.heading = QiblaCalculator.normalize(heading + change * 0.22)
        } else {
            heading = measuredHeading
        }

        accuracy = newHeading.headingAccuracy
        state = .updating
    }
}

extension HeadingProvider: @MainActor CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        publish(newHeading)
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        guard isActive else { return false }
        return accuracy.map { $0 > 20 } ?? false
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard isActive else { return }
        heading = nil
        accuracy = nil
        state = .unavailable
    }
}
