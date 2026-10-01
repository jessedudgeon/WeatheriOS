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
        switch manager.authorizationStatus {
        case .notDetermined:
            // Do not expire the request while the person is reading the permission prompt.
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: beginUpdates()
        case .denied, .restricted:
            finish(message: "Location access is off. Open Location Settings to allow Weather, or search for a city.")
        @unknown default: finish(message: "Location isn’t available. Search for a city instead.")
        }
    }

    private func beginUpdates() {
        guard isLocating else { return }
        timeout?.cancel()
        timeout = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 25_000_000_000)
            guard !Task.isCancelled, let self, self.isLocating else { return }
            #if targetEnvironment(simulator)
            self.finish(message: "The simulator has no location fix. In Simulator, choose Features → Location → Custom Location, or search for a city here.")
            #else
            self.finish(message: "No location fix was received. Check that Location Services and Wi-Fi are enabled, then retry. You can also search for a city.")
            #endif
        }
        // A one-shot request may fail with locationUnknown before a Mac or simulator
        // has a fix. Keep listening briefly and stop as soon as a usable fix arrives.
        manager.startUpdatingLocation()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in self?.authorizationChanged() }
    }

    private func authorizationChanged() {
        guard isLocating else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: beginUpdates()
        case .denied, .restricted:
            finish(message: "Location access is off. Open Location Settings to allow Weather, or search for a city.")
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
        let code = (error as? CLError)?.code
        Task { @MainActor [weak self] in
            guard let self, self.isLocating else { return }
            if code == .locationUnknown { return } // Wait for the next fix or the timeout.
            if code == .denied {
                self.finish(message: "Location access is off. Open Location Settings, or use city search.")
            } else {
                self.finish(message: "Couldn’t determine your location. Check Location Services and Wi-Fi, or search for a city.")
            }
        }
    }

    func cancel() { finish(message: nil) }

    private func finish(message: String?) {
        timeout?.cancel()
        manager.stopUpdatingLocation()
        isLocating = false
        self.message = message
    }
}
