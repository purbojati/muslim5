import CoreLocation
import Foundation

@MainActor
final class LocationProvider: NSObject, ObservableObject {
    enum State: Equatable {
        case idle
        case requesting
        case ready
        case denied
        case unavailable
    }

    @Published private(set) var coordinate: CLLocationCoordinate2D?
    @Published private(set) var state: State = .idle

    private let manager = CLLocationManager()
    private let defaults = UserDefaults.standard

    private enum StorageKey {
        static let latitude = "lastPrayerLatitude"
        static let longitude = "lastPrayerLongitude"
    }

    override init() {
        let latitude = defaults.object(forKey: StorageKey.latitude) as? Double
        let longitude = defaults.object(forKey: StorageKey.longitude) as? Double

        if let latitude, let longitude {
            coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            state = .ready
        }

        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            state = coordinate == nil ? .requesting : .ready
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            requestLocation()
        case .denied, .restricted:
            state = coordinate == nil ? .denied : .ready
        @unknown default:
            state = coordinate == nil ? .unavailable : .ready
        }
    }

    func requestLocation() {
        guard CLLocationManager.locationServicesEnabled() else {
            state = coordinate == nil ? .unavailable : .ready
            return
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            state = coordinate == nil ? .requesting : .ready
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            state = coordinate == nil ? .requesting : .ready
            manager.requestLocation()
        case .denied, .restricted:
            state = coordinate == nil ? .denied : .ready
        @unknown default:
            state = coordinate == nil ? .unavailable : .ready
        }
    }

    private func store(_ location: CLLocation) {
        coordinate = location.coordinate
        defaults.set(location.coordinate.latitude, forKey: StorageKey.latitude)
        defaults.set(location.coordinate.longitude, forKey: StorageKey.longitude)
        state = .ready
    }
}

extension LocationProvider: @MainActor CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            requestLocation()
        case .denied, .restricted:
            state = coordinate == nil ? .denied : .ready
        case .notDetermined:
            state = coordinate == nil ? .requesting : .ready
        @unknown default:
            state = coordinate == nil ? .unavailable : .ready
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        store(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        state = coordinate == nil ? .unavailable : .ready
    }
}
