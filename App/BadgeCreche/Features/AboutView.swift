import SwiftUI

/// À propos, confidentialité et mentions légales.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(CrecheStats.consentKey) private var sharesCrecheStats = false

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

                Section("Vos données vous appartiennent") {
                    Label {
                        Text("Votre QR code, le nom de votre enfant et votre position ne quittent jamais votre iPhone : ils ne sont stockés ni dans le cloud ni sur un serveur, et l'APPC n'y a jamais accès.")
                    } icon: {
                        Image(systemName: "icloud.slash")
                    }
                    Label {
                        Text("Vos données vous appartiennent entièrement. Vous pouvez les modifier ou les effacer à tout moment ; elles ne sont ni vendues, ni partagées. Le badge est même exclu des sauvegardes iCloud de l'iPhone.")
                    } icon: {
                        Image(systemName: "hand.raised")
                    }
                    Label {
                        Text("Votre position sert uniquement, au moment de créer le badge, à trier les crèches par distance. Le calcul se fait sur l'iPhone : la position n'est ni enregistrée ni transmise.")
                    } icon: {
                        Image(systemName: "location")
                    }
                    if CrecheStats.isAvailable {
                        Toggle(isOn: $sharesCrecheStats) {
                            Label {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Partager le nom de ma crèche, de façon anonyme")
                                    Text("Facultatif, désactivé par défaut. Si vous l'activez, seuls le nom de la crèche et la façon dont vous l'avez choisie sont envoyés aux statistiques de l'APPC (Matomo, hébergé par l'association), une fois à l'enregistrement du badge.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "chart.bar")
                            }
                        }
                    }
                    Text("Ce qui relève d'Apple, et non de l'application : la recherche d'une adresse hors liste interroge Apple Plans, et si vous avez activé la synchronisation iCloud de Wallet, Apple synchronise le badge entre vos appareils (désactivable dans les réglages iCloud).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link("Politique de confidentialité", destination: AppConfig.privacyPolicyURL)
                }

                Section("Mentions légales") {
                    legalRow("Éditeur", "\(AppConfig.associationName) (\(AppConfig.associationShortName))")
                    legalRow("Statut", AppConfig.legalRegistration)
                    legalRow("Siège", AppConfig.legalSeat)
                    legalRow("Directeur de la publication", AppConfig.publicationDirector)
                    legalRow("Données personnelles", personalDataNotice)
                    legalRow("Liste des crèches", "Contient des données de l'Apur (Atelier parisien d'urbanisme) sous licence ODbL, avec des adresses de la Base Adresse Nationale (Licence Ouverte).")
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

    private var personalDataNotice: String {
        let base = "Le QR code, le nom de l'enfant et votre position restent sur votre appareil : ils ne sont jamais collectés ni transmis. Vos données vous appartiennent entièrement."
        guard CrecheStats.isAvailable else { return base }
        return base + " Seule exception, facultative et désactivée par défaut : le partage anonyme du nom de la crèche pour les statistiques de l'APPC."
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
