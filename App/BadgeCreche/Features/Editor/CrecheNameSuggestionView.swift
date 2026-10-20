import SwiftUI

/// Proposer le nom d'usage de la crèche (ou signaler une crèche absente de la liste) : la messagerie du
/// parent s'ouvre avec un e-mail prêt à envoyer à l'APPC, qui corrige la liste pour tous les parents.
struct CrecheNameSuggestionView: View {
    let address: CrecheAddress

    @Environment(\.dismiss) private var dismiss
    @State private var proposedName = ""
    /// Référence dans la liste embarquée, retrouvée d'après le nom et l'adresse ; nil hors liste.
    @State private var crecheID: String?
    @State private var showsManualSending = false

    private var suggestion: CrecheNameSuggestion {
        CrecheNameSuggestion(proposedName: proposedName, currentName: address.name, address: address.label, crecheID: crecheID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dans l'application") {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(address.name ?? "Sans nom")
                            .font(.headline)
                        Text(address.label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    TextField("Nom utilisé par les parents", text: $proposedName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.send)
                        .onSubmit(send)
                } header: {
                    Text("Nom d'usage")
                } footer: {
                    Text("Par exemple « Halte-garderie Montmartre ». Votre messagerie s'ouvre avec un e-mail prêt à envoyer à l'APPC, qui met à jour la liste pour tous les parents dans une prochaine version. Seuls ce nom, le nom actuel et l'adresse de la crèche sont envoyés, avec votre adresse e-mail.")
                }
            }
            .navigationTitle("Proposer un nom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Envoyer", action: send)
                        .disabled(!suggestion.isValid)
                }
            }
            .task {
                crecheID = await CrecheCatalog.shared.load()?.creches
                    .first { $0.name == address.name && $0.fullAddress == address.label }?.id
            }
            .alert("Aucune messagerie configurée", isPresented: $showsManualSending) {
                Button("Copier le message") {
                    UIPasteboard.general.string = suggestion.body
                    dismiss()
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Copiez le message et envoyez-le à \(AppConfig.suggestionsEmail).")
            }
        }
    }

    private func send() {
        guard suggestion.isValid, let url = suggestion.mailtoURL(to: AppConfig.suggestionsEmail) else { return }
        Task {
            if await UIApplication.shared.open(url) {
                dismiss()
            } else {
                showsManualSending = true
            }
        }
    }
}
