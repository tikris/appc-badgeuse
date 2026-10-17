import SwiftUI

/// Liste des crèches embarquée dans l'application (Resources/creches-paris.json).
@MainActor
enum CrecheCatalog {
    static let paris: CrecheDirectory? = Bundle.main
        .url(forResource: "creches-paris", withExtension: "json")
        .flatMap { try? Data(contentsOf: $0) }
        .flatMap { try? CrecheDirectory(data: $0) }
}

/// Choix de la crèche : les 3 plus proches de la position, sinon la liste complète.
struct CrecheSection: View {
    @Binding var address: CrecheAddress?
    /// Appelé avec le nom de la crèche choisie (pour préremplir le nom affiché sur le badge).
    let onSelect: (String) -> Void
    /// Demande la position dès l'affichage (création d'un nouveau badge).
    let locatesOnAppear: Bool

    @StateObject private var location = LocationProvider()

    var body: some View {
        Section {
            if let address {
                AddressMap(address: address)
                    .frame(height: 150)
                    .listRowInsets(EdgeInsets())
                VStack(alignment: .leading, spacing: 2) {
                    Text(address.name ?? "Votre crèche")
                        .font(.headline)
                    Text(address.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Button("Choisir une autre crèche") {
                    self.address = nil
                    location.locate()
                }
            } else {
                suggestions
                NavigationLink {
                    CrecheListView(directory: CrecheCatalog.paris, onSelect: select, onManualAddress: selectManual)
                } label: {
                    Label("Autre crèche", systemImage: "list.bullet")
                }
            }
        } header: {
            Text("Votre crèche")
        } footer: {
            Text("Votre position sert uniquement à trier les crèches, sur l'iPhone : elle n'est ni enregistrée ni transmise. Le badge s'affichera sur l'écran verrouillé devant la crèche (à \(PassBuilder.relevantDistance) m maximum).")
        }
        .onAppear {
            if locatesOnAppear, address == nil, location.status == .idle {
                location.locate()
            }
        }
    }

    @ViewBuilder
    private var suggestions: some View {
        switch location.status {
        case .idle:
            Button {
                location.locate()
            } label: {
                Label("Trouver les crèches autour de moi", systemImage: "location")
            }
        case .locating:
            HStack(spacing: 12) {
                ProgressView()
                Text("Recherche des crèches proches…")
                    .foregroundStyle(.secondary)
            }
        case .located(let latitude, let longitude):
            ForEach(CrecheCatalog.paris?.nearest(latitude: latitude, longitude: longitude) ?? [], id: \.creche.id) { nearby in
                Button {
                    select(nearby.creche)
                } label: {
                    CrecheRow(creche: nearby.creche, distance: nearby.distance)
                }
            }
        case .denied:
            Text("Localisation non autorisée : choisissez votre crèche dans la liste (Réglages > Badge Crèche pour l'activer).")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .failed:
            Text("Position introuvable pour le moment : choisissez votre crèche dans la liste.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func select(_ creche: Creche) {
        address = creche.badgeAddress
        onSelect(creche.name)
    }

    private func selectManual(_ manual: CrecheAddress) {
        address = manual
        onSelect(manual.name ?? "")
    }
}

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

/// Toutes les crèches de Paris, par arrondissement, avec recherche.
struct CrecheListView: View {
    let directory: CrecheDirectory?
    let onSelect: (Creche) -> Void
    let onManualAddress: (CrecheAddress) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var groups: [(title: String, creches: [Creche])] {
        let results = directory?.search(query) ?? []
        return Dictionary(grouping: results, by: \.arrondissementNumber)
            .sorted { $0.key < $1.key }
            .map { (title: $0.value[0].arrondissement, creches: $0.value) }
    }

    var body: some View {
        List {
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
                if let directory {
                    Text("\(directory.creches.count) établissements. Source : \(directory.source). Licence : \(directory.licence). Mise à jour : \(directory.generated).")
                }
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Nom, rue ou arrondissement")
        .navigationTitle("Choisir une crèche")
        .navigationBarTitleDisplayMode(.inline)
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
