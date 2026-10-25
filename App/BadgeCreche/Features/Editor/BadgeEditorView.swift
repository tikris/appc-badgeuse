import SwiftUI

/// Création / modification du badge : crèche (proposée d'après la position), QR code,
/// et ce qui s'affiche sur le badge (noms de la crèche et de l'enfant, facultatifs).
struct BadgeEditorView: View {
    let existing: BadgeData?
    let onSave: (BadgeData) throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var qrPayload: String?
    @State private var showsChildName: Bool
    @State private var childFirstName: String
    @State private var childLastName: String
    @State private var showsCrecheName: Bool
    @State private var crecheName: String
    @State private var address: CrecheAddress?
    @State private var lockScreenDistance: LockScreenDistance
    /// Pour les statistiques facultatives : comment la crèche a été choisie pendant cette édition.
    @State private var crecheChoice: (source: CrecheStat.Source, creche: Creche?)?
    @AppStorage(CrecheStats.consentKey) private var sharesCrecheStats = false

    @State private var errorMessage: String?

    /// `prefill` : valeurs initiales d'un nouveau badge (captures d'écran).
    init(existing: BadgeData?, prefill: BadgeData? = nil, onSave: @escaping (BadgeData) throws -> Void) {
        self.existing = existing
        self.onSave = onSave
        let initial = existing ?? prefill
        _qrPayload = State(initialValue: initial?.qrPayload)
        _showsChildName = State(initialValue: initial?.showsChildName ?? false)
        _childFirstName = State(initialValue: initial?.childFirstName ?? "")
        _childLastName = State(initialValue: initial?.childLastName ?? "")
        let storedName = existing?.crecheName ?? ""
        _showsCrecheName = State(initialValue: existing == nil || !storedName.isEmpty)
        _crecheName = State(initialValue: storedName.isEmpty ? (existing?.address.name ?? "") : storedName)
        // Pour un nouveau badge, la crèche est choisie d'après la position (pas de préremplissage).
        _address = State(initialValue: existing?.address)
        _lockScreenDistance = State(initialValue: existing?.lockScreenDistance ?? .standard)
    }

    private var canSave: Bool {
        qrPayload != nil && address != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                CrecheSection(address: $address, lockScreenDistance: $lockScreenDistance, onSelect: { name, source, creche in
                    crecheName = name
                    crecheChoice = (source, creche)
                }, locatesOnAppear: existing == nil)
                QRCodeSection(payload: $qrPayload)
                displaySection
                if CrecheStats.isAvailable {
                    statsSection
                }
            }
            .navigationTitle(existing == nil ? "Nouveau badge" : "Modifier le badge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer", action: save)
                        .disabled(!canSave)
                }
            }
            .alert("Enregistrement impossible", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: Sections

    private var displaySection: some View {
        Section {
            Toggle("Afficher le nom de la crèche", isOn: $showsCrecheName.animation())
            if showsCrecheName {
                TextField("Nom de la crèche", text: $crecheName)
                    .textInputAutocapitalization(.words)
            }
            Toggle("Afficher le nom de l'enfant", isOn: $showsChildName.animation())
            if showsChildName {
                TextField("Prénom", text: $childFirstName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                TextField("Nom (facultatif)", text: $childLastName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }
        } header: {
            Text("Sur le badge (facultatif)")
        } footer: {
            Text("Uniquement si vous le souhaitez. Ces informations restent sur votre iPhone et dans Apple Wallet : elles ne sont jamais transmises à l'APPC.")
        }
    }

    private var statsSection: some View {
        Section {
            Toggle("Partager le nom de ma crèche, de façon anonyme", isOn: $sharesCrecheStats)
        } header: {
            Text("Aider l'APPC (facultatif)")
        } footer: {
            Text("Pour savoir dans quelles crèches l'application est utilisée. Seuls le nom de la crèche et la façon dont vous l'avez choisie sont envoyés, une fois, à l'enregistrement : jamais le QR code, le nom de l'enfant ni votre position. Modifiable à tout moment dans À propos.")
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    // MARK: Actions

    private func save() {
        guard let qrPayload, let address else { return }
        let firstName = childFirstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastName = childLastName.trimmingCharacters(in: .whitespacesAndNewlines)
        // Minimisation : le nom n'est conservé que si le parent a choisi de l'afficher.
        let keepsName = showsChildName && !(firstName.isEmpty && lastName.isEmpty)
        var badge = BadgeData(
            serialNumber: existing?.serialNumber ?? UUID().uuidString,
            qrPayload: qrPayload,
            showsChildName: keepsName,
            childFirstName: keepsName ? firstName : "",
            childLastName: keepsName ? lastName : "",
            crecheName: showsCrecheName ? crecheName.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            address: address,
            updatedAt: Date()
        )
        badge.lockScreenDistance = lockScreenDistance
        do {
            try onSave(badge)
            if let crecheChoice, existing?.address != address {
                CrecheStats.send(CrecheStat(
                    event: existing == nil ? .created : .crecheChanged,
                    source: crecheChoice.source,
                    creche: crecheChoice.creche
                ))
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
