import Foundation
import Combine
import CoreLocation

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var isLocating = false
    @Published var message: String?
    var onLocation: ((CLLocation) -> Void)?
    private let manager = CLLocationManager()
    private var timeout: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func request() {
        guard !isLocating else { return }
        message = nil
        isLocating = true
        timeout?.cancel()
        timeout = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            guard !Task.isCancelled, let self, self.isLocating else { return }
            self.finish(message: "Location took too long. Try again or search for a city.")
        }
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted:
            finish(message: "Location access is off. Search for a city, or allow Weather in your device’s Location Services settings.")
        @unknown default: finish(message: "Location isn’t available. Search for a city instead.")
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in self?.authorizationChanged() }
    }

    private func authorizationChanged() {
        guard isLocating else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted:
            finish(message: "Location access is off. You can still search for any city.")
        default: break
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in
            guard let self, self.isLocating, let location = locations.last,
                  location.horizontalAccuracy >= 0,
                  abs(location.timestamp.timeIntervalSinceNow) < 300 else { return }
            self.finish(message: nil)
            self.onLocation?(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self, self.isLocating else { return }
            self.finish(message: "Couldn’t get your location. Try again or search for a city.")
        }
    }

    func cancel() {
        finish(message: nil)
    }

    private func finish(message: String?) {
        timeout?.cancel()
        manager.stopUpdatingLocation()
        isLocating = false
        self.message = message
    }
}
