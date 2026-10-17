import SwiftUI

/// Premier lancement : explique le principe en trois étapes.
struct WelcomeView: View {
    let onStart: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Image(uiImage: PassArtwork.appIcon(side: 96))
                    .resizable()
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("Votre badge de crèche dans Apple Wallet")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text("Plus besoin de chercher le badge : il s'affiche tout seul sur l'écran verrouillé quand vous arrivez à la crèche.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 18) {
                    step(
                        symbol: "mappin.and.ellipse",
                        title: "Choisissez votre crèche",
                        detail: "Les plus proches vous sont proposées ; toutes les crèches de Paris sont dans la liste."
                    )
                    step(
                        symbol: "qrcode.viewfinder",
                        title: "Scannez le QR code de la crèche",
                        detail: "Celui remis en début d'année, ou importez-le depuis une photo ou un PDF."
                    )
                    step(
                        symbol: "wallet.pass",
                        title: "Ajoutez-le à Apple Wallet",
                        detail: "Tout reste sur votre iPhone : rien n'est stocké dans le cloud, vos données vous appartiennent."
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onStart) {
                    Text("Créer mon badge")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("Une initiative de l'association Parents à Paris Centre (APPC)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
    }

    private func step(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Color.appcCoral)
                .frame(width: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
