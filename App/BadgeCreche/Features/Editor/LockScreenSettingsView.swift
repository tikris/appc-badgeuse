import MapKit
import SwiftUI

/// Réglage de l'affichage sur l'écran verrouillé : distance à laquelle Wallet propose le badge et
/// emplacement exact de l'entrée, que le parent corrige d'une touche sur la carte (vue satellite).
struct LockScreenSettingsView: View {
    let address: CrecheAddress
    let onSave: (_ address: CrecheAddress, _ distance: LockScreenDistance) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var distance: LockScreenDistance
    @State private var entrance: CLLocationCoordinate2D
    @State private var camera: MapCameraPosition

    init(
        address: CrecheAddress,
        distance: LockScreenDistance,
        onSave: @escaping (_ address: CrecheAddress, _ distance: LockScreenDistance) -> Void
    ) {
        self.address = address
        self.onSave = onSave
        let coordinate = address.coordinate
        _distance = State(initialValue: distance)
        _entrance = State(initialValue: coordinate)
        _camera = State(initialValue: .camera(MapCamera(centerCoordinate: coordinate, distance: 300)))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                map
                controls
            }
            .navigationTitle("Écran verrouillé")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK", action: save)
                }
            }
        }
        // Un glissement sur la carte ne doit pas fermer la fiche et perdre le réglage.
        .interactiveDismissDisabled()
    }

    private var map: some View {
        MapReader { proxy in
            Map(position: $camera) {
                if let meters = distance.meters {
                    MapCircle(center: entrance, radius: CLLocationDistance(meters))
                        .foregroundStyle(Color.appcCoral.opacity(0.25))
                        .stroke(Color.appcCoral, lineWidth: 2)
                }
                Marker("Entrée", systemImage: "door.left.hand.open", coordinate: entrance)
                    .tint(Color.appcCoral)
                UserAnnotation()
            }
            .mapStyle(.hybrid(elevation: .flat, pointsOfInterest: .excludingAll))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .onTapGesture { point in
                if let coordinate = proxy.convert(point, from: .local) {
                    entrance = coordinate
                }
            }
            .accessibilityLabel("Carte de la crèche : touchez l'endroit de l'entrée")
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Repère pas tout à fait sur la porte ? Touchez la carte à l'endroit exact de l'entrée.", systemImage: "hand.tap")
                .font(.subheadline)
            Text("Proposer le badge à")
                .font(.headline)
            Picker("Proposer le badge à", selection: $distance) {
                ForEach(LockScreenDistance.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            Text(distance.explanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }

    private func save() {
        var updated = address
        updated.latitude = entrance.latitude
        updated.longitude = entrance.longitude
        onSave(updated, distance)
        dismiss()
    }
}

extension LockScreenDistance {
    /// Libellé court : sélecteur, ligne de l'éditeur.
    var title: String {
        meters.map { "\($0) m" } ?? "Jamais"
    }

    var explanation: String {
        switch self {
        case .door: "Le plus près possible. iOS décide du moment exact et, en ville, la position de l'iPhone varie de quelques dizaines de mètres : le badge peut apparaître un peu avant la porte."
        case .street: "Le badge apparaît en arrivant dans la rue de la crèche."
        case .approach: "Le badge apparaît à l'approche de la crèche : plus tôt, mais plus régulièrement."
        case .never: "Le badge ne s'affiche plus tout seul. Pour l'ouvrir : double-cliquez sur le bouton latéral."
        }
    }
}
