import MapKit
import SwiftUI

/// Réglage de l'affichage sur l'écran verrouillé : distance à laquelle Wallet propose le badge,
/// créneaux horaires facultatifs (iOS 18 et plus) et emplacement exact de l'entrée, que le parent
/// corrige d'une touche sur la carte (vue satellite).
struct LockScreenSettingsView: View {
    let address: CrecheAddress
    let onSave: (_ address: CrecheAddress, _ distance: LockScreenDistance, _ crecheHoursOnly: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var distance: LockScreenDistance
    @State private var crecheHoursOnly: Bool
    @State private var entrance: CLLocationCoordinate2D
    @State private var camera: MapCameraPosition

    init(
        address: CrecheAddress,
        distance: LockScreenDistance,
        crecheHoursOnly: Bool,
        onSave: @escaping (_ address: CrecheAddress, _ distance: LockScreenDistance, _ crecheHoursOnly: Bool) -> Void
    ) {
        self.address = address
        self.onSave = onSave
        let coordinate = address.coordinate
        // 25 m n'est plus proposé : il se confond avec le réglage le plus serré.
        _distance = State(initialValue: LockScreenDistance.choices.contains(distance) ? distance : .door)
        _crecheHoursOnly = State(initialValue: crecheHoursOnly)
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
            Text("Proposer le badge")
                .font(.headline)
            Picker("Proposer le badge", selection: $distance) {
                ForEach(LockScreenDistance.choices) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            Text(distance.explanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            // Créneaux horaires : `relevantDates`, pris en compte à partir d'iOS 18.
            if distance != .never {
                if #available(iOS 18, *) {
                    Toggle("Seulement aux heures de crèche", isOn: $crecheHoursOnly)
                        .font(.subheadline)
                    Text("Le badge n'est proposé que \(CrecheHours.summary) : plus le soir, la nuit ni le week-end, même près de la crèche. Ouvrez l'app au moins une fois tous les six mois pour prolonger ces horaires.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }

    private func save() {
        var updated = address
        updated.latitude = entrance.latitude
        updated.longitude = entrance.longitude
        onSave(updated, distance, crecheHoursOnly)
        dismiss()
    }
}

extension LockScreenDistance {
    /// Libellé court : sélecteur, ligne de l'éditeur. Pas de distance affichée : iOS y ajoute
    /// l'imprécision de la position, et la promesse ne serait pas tenue.
    var title: String {
        switch self {
        case .door: "Au plus près"
        case .street: "Un peu avant"
        case .approach: "Plus tôt"
        case .never: "Jamais"
        }
    }

    var explanation: String {
        switch self {
        case .door: "Le réglage le plus serré. En ville, l'iPhone ne connaît sa position qu'à quelques dizaines de mètres près, et c'est iOS qui décide du moment : le badge apparaît souvent un peu avant la porte. Proposé trop tôt sur votre trajet ? Placez le repère 15 à 20 m au-delà de la porte, à l'opposé de votre arrivée, puis vérifiez sur place qu'il apparaît toujours."
        case .street: "Un peu avant la porte : c'est iOS qui décide du moment exact."
        case .approach: "Plus tôt, à l'approche de la crèche, mais plus régulièrement."
        case .never: "Le badge ne s'affiche plus tout seul. Pour l'ouvrir : double-cliquez sur le bouton latéral."
        }
    }
}
