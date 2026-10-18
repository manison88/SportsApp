import Foundation
import CoreLocation
import Observation

/// When-in-use location for live check-in.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    var location: CLLocation?
    var authorized = false
    /// The fan said no (or it is restricted): asking again will not show a prompt.
    var denied = false

    @ObservationIgnored private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        authorized = Self.isAuthorized(manager.authorizationStatus)
        denied = Self.isDenied(manager.authorizationStatus)
    }

    func start() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    static func nearestVenue(to location: CLLocation, in venues: [Venue], within: CLLocationDistance = 1000) -> Venue? {
        venues.map { ($0, $0.location.distance(from: location)) }
            .filter { $0.1 <= within }
            .min { $0.1 < $1.1 }?.0
    }

    private static func isDenied(_ s: CLAuthorizationStatus) -> Bool { s == .denied || s == .restricted }

    private static func isAuthorized(_ s: CLAuthorizationStatus) -> Bool {
        s == .authorizedWhenInUse || s == .authorizedAlways
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in self.location = last }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorized = Self.isAuthorized(status)
            self.denied = Self.isDenied(status)
            if self.authorized { self.manager.startUpdatingLocation() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
