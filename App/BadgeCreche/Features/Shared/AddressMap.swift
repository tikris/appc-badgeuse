import MapKit
import SwiftUI

/// Carte de confirmation de la crèche, avec la zone d'affichage automatique sur l'écran verrouillé.
struct AddressMap: View {
    let address: CrecheAddress
    var distance: LockScreenDistance = .standard

    var body: some View {
        let coordinate = address.coordinate
        Map(
            initialPosition: .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 150, longitudinalMeters: 150)),
            interactionModes: []
        ) {
            if let meters = distance.meters {
                MapCircle(center: coordinate, radius: CLLocationDistance(meters))
                    .foregroundStyle(Color.appcCoral.opacity(0.2))
                    .stroke(Color.appcCoral, lineWidth: 1)
            }
            Marker(address.name ?? "Crèche", systemImage: "figure.and.child.holdinghands", coordinate: coordinate)
                .tint(Color.appcCoral)
        }
        .id(address)
        .accessibilityLabel("Carte de la crèche : \(address.label)")
    }
}

extension CrecheAddress {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
