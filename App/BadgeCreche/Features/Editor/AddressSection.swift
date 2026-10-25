import MapKit
import SwiftUI

/// Recherche de l'adresse de la crèche via Apple Plans (pas de clé d'API, pas de localisation requise).
struct AddressSection: View {
    @Binding var address: CrecheAddress?

    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false
    @State private var message: String?

    var body: some View {
        Section {
            if let address {
                AddressMap(address: address)
                    .frame(height: 170)
                    .listRowInsets(EdgeInsets())
                Label(address.label, systemImage: "mappin.and.ellipse")
                Button("Changer d'adresse") {
                    self.address = nil
                }
            } else {
                HStack {
                    TextField("Adresse ou nom de la crèche", text: $query)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit(search)
                    if isSearching {
                        ProgressView()
                    } else {
                        Button(action: search) {
                            Image(systemName: "magnifyingglass")
                        }
                        .buttonStyle(.borderless)
                        .disabled(trimmedQuery.isEmpty)
                        .accessibilityLabel("Rechercher")
                    }
                }
                ForEach(results, id: \.self) { item in
                    Button {
                        select(item)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name ?? "Adresse")
                                .foregroundStyle(.primary)
                            if let subtitle = item.placemark.title {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Adresse de la crèche")
        } footer: {
            Text("Recherche effectuée avec Apple Plans.")
        }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func search() {
        guard !trimmedQuery.isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmedQuery
        // Recherche orientée vers Paris Centre.
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.8606, longitude: 2.3522),
            latitudinalMeters: 15_000,
            longitudinalMeters: 15_000
        )
        request.resultTypes = [.address, .pointOfInterest]
        isSearching = true
        message = nil
        Task {
            defer { isSearching = false }
            do {
                let response = try await MKLocalSearch(request: request).start()
                results = Array(response.mapItems.prefix(6))
                if results.isEmpty {
                    message = "Aucun résultat. Essayez « numéro, rue, Paris »."
                }
            } catch {
                results = []
                message = "Aucun résultat. Vérifiez l'adresse (ex. « 2 rue de Rivoli, Paris ») et votre connexion."
            }
        }
    }

    private func select(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        let addressLine = item.placemark.title ?? ""
        let name = item.name ?? ""
        let isPlace = !name.isEmpty && !addressLine.hasPrefix(name)
        address = CrecheAddress(
            label: addressLine.isEmpty ? name : addressLine,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            name: isPlace ? name : nil
        )
        results = []
        query = ""
    }
}
