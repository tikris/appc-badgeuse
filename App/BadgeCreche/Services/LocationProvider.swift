import Combine
import CoreLocation

/// Position ponctuelle, uniquement pour trier les crèches par distance.
/// Elle reste sur l'iPhone : jamais enregistrée ni transmise.
@MainActor
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum Status: Equatable {
        case idle
        case locating
        case located(latitude: Double, longitude: Double)
        case denied
        case failed
    }

    @Published private(set) var status: Status = .idle
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func locate() {
        if let demo = ScreenshotMode.demoLocation {
            status = .located(latitude: demo.latitude, longitude: demo.longitude)
            return
        }
        switch manager.authorizationStatus {
        case .notDetermined:
            status = .locating
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            status = .locating
            manager.requestLocation()
        default:
            status = .denied
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let authorization = manager.authorizationStatus
        MainActor.assumeIsolated {
            guard status == .locating else { return }
            switch authorization {
            case .authorizedWhenInUse, .authorizedAlways:
                self.manager.requestLocation()
            case .denied, .restricted:
                status = .denied
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        MainActor.assumeIsolated {
            status = .located(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let isDenied = (error as? CLError)?.code == .denied
        MainActor.assumeIsolated {
            status = isDenied ? .denied : .failed
        }
    }
}
