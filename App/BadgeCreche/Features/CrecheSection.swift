import SwiftUI

/// Liste des crèches embarquée (Resources/creches-paris.json) : environ 1 200 fiches lues et indexées
/// une seule fois, hors du fil principal, pour ne jamais figer l'interface.
@MainActor
@Observable
final class CrecheCatalog {
    static let shared = CrecheCatalog()

    /// nil tant que la liste n'est pas chargée (ou si le fichier manque).
    private(set) var paris: CrecheDirectory?
    private(set) var isLoaded = false
    @ObservationIgnored private var loading: Task<CrecheDirectory?, Never>?

    private init() {}

    /// Lance le chargement si besoin et attend la liste ; les appels simultanés partagent le même chargement.
    @discardableResult
    func load() async -> CrecheDirectory? {
        if isLoaded { return paris }
        let task = loading ?? Task.detached(priority: .userInitiated) { Self.readBundledList() }
        loading = task
        let directory = await task.value
        paris = directory
        isLoaded = true
        return directory
    }

    private nonisolated static func readBundledList() -> CrecheDirectory? {
        Bundle.main.url(forResource: "creches-paris", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? CrecheDirectory(data: $0) }
    }
}

/// Choix de la crèche : les 3 plus proches de la position, sinon la liste complète.
struct CrecheSection: View {
    @Binding var address: CrecheAddress?
    /// Appelé avec le nom de la crèche choisie (pour préremplir le nom affiché sur le badge), la façon
    /// dont elle l'a été et la crèche de la liste (statistiques facultatives, voir CrecheStat).
    let onSelect: (_ name: String, _ source: CrecheStat.Source, _ creche: Creche?) -> Void
    /// Demande la position dès l'affichage (création d'un nouveau badge).
    let locatesOnAppear: Bool

    @StateObject private var location = LocationProvider()
    /// Les 3 plus proches, calculées une fois par position (nil pendant le calcul).
    @State private var nearby: [NearbyCreche]?

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
                    CrecheListView(onSelect: { select($0, source: .list) }, onManualAddress: selectManual)
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
        .task {
            await CrecheCatalog.shared.load()
        }
        .task(id: location.status) {
            guard case .located(let latitude, let longitude) = location.status else { return }
            nearby = nil
            nearby = await CrecheCatalog.shared.load()?.nearest(latitude: latitude, longitude: longitude) ?? []
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
        case .located:
            if let nearby {
                ForEach(nearby, id: \.creche.id) { item in
                    Button {
                        select(item.creche, source: .nearby)
                    } label: {
                        CrecheRow(creche: item.creche, distance: item.distance)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Recherche des crèches proches…")
                        .foregroundStyle(.secondary)
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

    private func select(_ creche: Creche, source: CrecheStat.Source) {
        address = creche.badgeAddress
        onSelect(creche.name, source, creche)
    }

    private func selectManual(_ manual: CrecheAddress) {
        address = manual
        onSelect(manual.name ?? "", .manual, nil)
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
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Chargement de la liste…")
                        .foregroundStyle(.secondary)
                }
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
