import SwiftUI

/// Choix de la crèche : les 3 plus proches de la position, sinon la liste complète ;
/// une fois choisie, carte et réglage de l'affichage sur l'écran verrouillé.
struct CrecheSection: View {
    @Binding var address: CrecheAddress?
    /// Distance d'affichage sur l'écran verrouillé, réglée avec l'emplacement de l'entrée.
    @Binding var lockScreenDistance: LockScreenDistance
    /// Appelé avec le nom de la crèche choisie (pour préremplir le nom affiché sur le badge), la façon
    /// dont elle l'a été et la crèche de la liste (statistiques facultatives, voir CrecheStat).
    let onSelect: (_ name: String, _ source: CrecheStat.Source, _ creche: Creche?) -> Void
    /// Demande la position dès l'affichage (création d'un nouveau badge).
    let locatesOnAppear: Bool

    @StateObject private var location = LocationProvider()
    /// Les 3 plus proches, calculées une fois par position (nil pendant le calcul).
    @State private var nearby: [NearbyCreche]?
    @State private var isEditingLockScreen = false
    @State private var isSuggestingName = false

    private static let searchingText = "Recherche des crèches proches…"

    var body: some View {
        Section {
            if let address {
                chosen(address)
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
            footer
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

    // MARK: Crèche choisie

    @ViewBuilder
    private func chosen(_ address: CrecheAddress) -> some View {
        AddressMap(address: address, distance: lockScreenDistance)
            .frame(height: 150)
            .listRowInsets(EdgeInsets())
        VStack(alignment: .leading, spacing: 2) {
            Text(address.name ?? "Votre crèche")
                .font(.headline)
            Text(address.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        Button {
            isEditingLockScreen = true
        } label: {
            LabeledContent {
                Text(lockScreenDistance.title)
            } label: {
                Label("Écran verrouillé", systemImage: "lock.iphone")
            }
        }
        .sheet(isPresented: $isEditingLockScreen) {
            LockScreenSettingsView(address: address, distance: lockScreenDistance) { newAddress, newDistance in
                self.address = newAddress
                lockScreenDistance = newDistance
            }
        }
        Button {
            isSuggestingName = true
        } label: {
            Label("Proposer le nom utilisé par les parents", systemImage: "square.and.pencil")
        }
        .sheet(isPresented: $isSuggestingName) {
            CrecheNameSuggestionView(address: address)
        }
        Button("Choisir une autre crèche") {
            self.address = nil
            location.locate()
        }
    }

    private var footer: Text {
        guard address != nil else {
            return Text("Votre position sert uniquement à trier les crèches, sur l'iPhone : elle n'est ni enregistrée ni transmise. Le badge s'affichera sur l'écran verrouillé devant la crèche.")
        }
        guard let meters = lockScreenDistance.meters else {
            return Text("Le badge ne s'affiche pas tout seul sur l'écran verrouillé.")
        }
        return Text("Le badge s'affiche sur l'écran verrouillé à \(meters) m maximum de l'entrée. « Écran verrouillé » : changer la distance ou placer l'entrée sur la carte.")
    }

    // MARK: Suggestions d'après la position

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
            ProgressRow(text: Self.searchingText)
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
                ProgressRow(text: Self.searchingText)
            }
        case .denied:
            hint("Localisation non autorisée : choisissez votre crèche dans la liste (Réglages > Badge Crèche pour l'activer).")
        case .failed:
            hint("Position introuvable pour le moment : choisissez votre crèche dans la liste.")
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    // MARK: Actions

    private func select(_ creche: Creche, source: CrecheStat.Source) {
        address = creche.badgeAddress
        onSelect(creche.name, source, creche)
    }

    private func selectManual(_ manual: CrecheAddress) {
        address = manual
        onSelect(manual.name ?? "", .manual, nil)
    }
}
