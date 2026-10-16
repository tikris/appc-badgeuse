import SwiftUI

/// À propos, confidentialité et mentions légales.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 10) {
                        Image(uiImage: PassArtwork.appIcon(side: 72))
                            .resizable()
                            .frame(width: 72, height: 72)
                            .accessibilityHidden(true)
                        Text(AppConfig.appName)
                            .font(.title2.bold())
                        Text("Version \(appVersion)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section("Une initiative de l'APPC") {
                    Text("Badge Crèche est une application gratuite et sans publicité, créée bénévolement par l'association Parents à Paris Centre (APPC) pour simplifier le quotidien des familles : le QR code de la badgeuse toujours à portée de main, dans Apple Wallet.")
                    Text("Vous êtes parent à Paris Centre ? Rejoignez la communauté de l'APPC pour échanger, vous entraider et suivre nos actions.")
                    Link(destination: AppConfig.whatsappCommunityURL) {
                        Label("Rejoindre la communauté WhatsApp", systemImage: "person.3.fill")
                    }
                }

                Section("Vos données") {
                    Text("Aucun compte, aucun serveur : le QR code, le nom de l'enfant et l'adresse restent sur votre iPhone et dans Apple Wallet. L'APPC n'y a jamais accès.")
                    Text("La recherche d'adresse passe par Apple Plans. Si la synchronisation iCloud de Wallet est activée, Apple synchronise le badge entre vos appareils.")
                    Link("Politique de confidentialité", destination: AppConfig.privacyPolicyURL)
                }

                Section("Mentions légales") {
                    legalRow("Éditeur", "\(AppConfig.associationName) (\(AppConfig.associationShortName))")
                    legalRow("Statut", AppConfig.legalRegistration)
                    legalRow("Siège", AppConfig.legalSeat)
                    legalRow("Directeur de la publication", AppConfig.publicationDirector)
                    if !AppConfig.contactEmail.isEmpty, let mail = URL(string: "mailto:\(AppConfig.contactEmail)") {
                        Link(destination: mail) {
                            legalRow("Contact", AppConfig.contactEmail)
                        }
                    }
                    Text("Application indépendante, non affiliée à la Ville de Paris ni aux gestionnaires de crèches. Apple Wallet est une marque d'Apple Inc.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link("Mentions légales complètes", destination: AppConfig.legalNoticeURL)
                    Link("Code source (licence GPL v3)", destination: AppConfig.sourceCodeURL)
                }
            }
            .navigationTitle("À propos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func legalRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
    }
}
