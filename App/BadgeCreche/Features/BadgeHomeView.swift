import PassKit
import SwiftUI

/// Écran principal une fois le badge créé : aperçu, ajout à Wallet, modification.
struct BadgeHomeView: View {
    let badge: BadgeData
    let store: BadgeStore
    let onEdit: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var pass: PKPass?
    @State private var isInWallet = false
    @State private var walletURL: URL?
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var isConfirmingDeletion = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                BadgeCardView(badge: badge)

                walletSection

                if let statusMessage {
                    Label(statusMessage, systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }

                tips

                VStack(spacing: 12) {
                    Button(action: onEdit) {
                        Label("Modifier le badge", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    Button(role: .destructive) {
                        isConfirmingDeletion = true
                    } label: {
                        Label("Supprimer le badge", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding()
        }
        .task(id: badge) {
            await preparePass()
        }
        .confirmationDialog("Supprimer le badge ?", isPresented: $isConfirmingDeletion, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive, action: deleteBadge)
        } message: {
            Text("Le badge sera effacé de cette application et, si possible, d'Apple Wallet.")
        }
        .alert("Impossible de préparer le badge", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var walletSection: some View {
        if !WalletService.isAvailable {
            Label("Apple Wallet n'est pas disponible sur cet appareil.", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        } else if isInWallet {
            VStack(spacing: 12) {
                Label("Badge présent dans Apple Wallet", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                if let walletURL {
                    Button {
                        openURL(walletURL)
                    } label: {
                        Label("Ouvrir dans Wallet", systemImage: "wallet.pass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        } else if let pass {
            VStack(spacing: 8) {
                AddPassToWalletButton([pass]) { added in
                    if added {
                        isInWallet = true
                        walletURL = WalletService.installedPass(matching: pass)?.passURL
                        statusMessage = "Badge ajouté à Apple Wallet."
                    }
                }
                .frame(height: 50)
                .addPassToWalletButtonStyle(.black)
                Text("Dernière étape : ajoutez votre badge à Apple Wallet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else if ScreenshotMode.scene != nil {
            StaticAddPassButton()
                .frame(height: 50)
        } else if errorMessage == nil {
            ProgressView()
        }
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Le badge s'affiche sur l'écran verrouillé à \(PassBuilder.relevantDistance) m maximum de la crèche (Service de localisation activé).", systemImage: "location")
            Label("À tout moment : double-cliquez sur le bouton latéral pour ouvrir Wallet.", systemImage: "hand.tap")
            Label("Testez-le une première fois à la badgeuse et gardez le badge d'origine en secours.", systemImage: "checkmark.shield")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func preparePass() async {
        guard ScreenshotMode.scene == nil else { return }
        do {
            let newPass = try await WalletService.makePass(for: badge)
            guard !Task.isCancelled else { return }
            pass = newPass
            if store.needsWalletRefresh, WalletService.replaceInWallet(with: newPass) {
                statusMessage = "Badge mis à jour dans Apple Wallet."
            }
            store.walletRefreshed()
            let installed = WalletService.installedPass(matching: newPass)
            isInWallet = installed != nil
            walletURL = installed?.passURL
        } catch {
            pass = nil
            errorMessage = error.localizedDescription
        }
    }

    private func deleteBadge() {
        if let pass {
            WalletService.removeFromWallet(pass)
        }
        store.delete()
    }
}
