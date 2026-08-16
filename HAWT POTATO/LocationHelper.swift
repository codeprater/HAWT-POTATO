import CoreLocation
import HAWTPotatoCore

@MainActor
final class LocationHelper: NSObject, CLLocationManagerDelegate {
    static let shared = LocationHelper()
    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<LocationSnapshot?, Never>?
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func snapshot(sharing: LocationSharing) async -> LocationSnapshot? {
        guard sharing != .hidden else { return nil }
        let status = await waitForAuthorization()
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return nil }
        manager.desiredAccuracy = sharing == .precise ? kCLLocationAccuracyNearestTenMeters : kCLLocationAccuracyKilometer
        return await withCheckedContinuation { continuation in
            self.locationContinuation = continuation
            manager.requestLocation()
        }
    }

    private func waitForAuthorization() async -> CLAuthorizationStatus {
        let current = manager.authorizationStatus
        if current != .notDetermined { return current }
        return await withCheckedContinuation { continuation in
            self.authContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let authContinuation else { return }
        guard manager.authorizationStatus != .notDetermined else { return }
        authContinuation.resume(returning: manager.authorizationStatus)
        self.authContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
            return
        }
        let sharing = manager.desiredAccuracy <= kCLLocationAccuracyNearestTenMeters ? LocationSharing.precise : LocationSharing.approximate
        let place: String
        if sharing == .approximate {
            place = "Nearby"
        } else {
            place = String(format: "%.3f, %.3f", location.coordinate.latitude, location.coordinate.longitude)
        }
        let snapshot = LocationSnapshot(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            placeName: place,
            sharing: sharing
        )
        locationContinuation?.resume(returning: snapshot)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
    }
}
