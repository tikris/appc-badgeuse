import SwiftUI

/// Toutes les crèches de Paris, par arrondissement, avec recherche.
struct CrecheListView: View {
    let onSelect: (Creche) -> Void
    let onManualAddress: (CrecheAddress) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    /// Recalculés seulement quand la recherche change, pas à chaque rafraîchissement de l'écran.
    @State private var groups: [(title: String, creches: [Creche])] = []
    private var catalog: CrecheCatalog { .shared }

    var body: some View {
        List {
            if !catalog.isLoaded {
                ProgressRow(text: "Chargement de la liste…")
            }
            ForEach(groups, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.creches) { creche in
                        Button {
                            onSelect(creche)
                            dismiss()
                        } label: {
                            CrecheRow(creche: creche)
                        }
                    }
                }
            }
            Section {
                NavigationLink("Ma crèche n'est pas dans la liste") {
                    ManualCrecheView { manual in
                        onManualAddress(manual)
                        dismiss()
                    }
                }
            } footer: {
                if let directory = catalog.paris {
                    Text("\(directory.creches.count) établissements. Source : \(directory.source). Licence : \(directory.licence). Mise à jour : \(directory.generated).")
                }
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Nom, rue ou arrondissement")
        .task(id: query) {
            let directory = await catalog.load()
            groups = CrecheDirectory.byArrondissement(directory?.search(query) ?? [])
        }
        .navigationTitle("Choisir une crèche")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Une crèche dans une liste : nom, adresse ou type, et distance si elle est connue.
struct CrecheRow: View {
    let creche: Creche
    var distance: Double?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(creche.name)
                    .foregroundStyle(.primary)
                Text(creche.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let distance {
                Text(Self.format(distance))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    static func format(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int((meters / 10).rounded()) * 10) m"
        }
        return String(format: "%.1f km", meters / 1000).replacingOccurrences(of: ".", with: ",")
    }
}

/// Dernier recours : crèche hors liste (privée, hors Paris…), cherchée dans Apple Plans.
struct ManualCrecheView: View {
    let onPick: (CrecheAddress) -> Void
    @State private var address: CrecheAddress?

    var body: some View {
        Form {
            AddressSection(address: $address)
        }
        .navigationTitle("Autre adresse")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: address) { _, picked in
            if let picked { onPick(picked) }
        }
    }
}
