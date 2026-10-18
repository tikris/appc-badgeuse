import Foundation
import PassKit

/// Création du pass signé et dialogue avec Apple Wallet.
///
/// Les opérations « est-il déjà dans Wallet ? / remplacer / supprimer » nécessitent la
/// capacité Wallet (entitlement) avec le Pass Type ID dans Xcode. Sans elle, l'ajout
/// fonctionne mais l'application ne voit pas le pass déjà présent.
@MainActor
enum WalletService {
    private static let library = PKPassLibrary()

    static let isAvailable = PKPassLibrary.isPassLibraryAvailable() && PKAddPassesViewController.canAddPasses()

    /// Pass signé, préparé hors du fil principal (import du certificat, signature, archive).
    static func makePass(for badge: BadgeData) async throws -> PKPass {
        let data = try await PassSigner.shared.pkpass(
            for: badge,
            images: PassArtwork.passImages,
            branding: AppConfig.passBranding
        )
        return try PKPass(data: data)
    }

    /// Le pass tel qu'enregistré dans Wallet, s'il y est.
    static func installedPass(matching pass: PKPass) -> PKPass? {
        library.pass(withPassTypeIdentifier: pass.passTypeIdentifier, serialNumber: pass.serialNumber)
    }

    /// Remplace silencieusement le pass déjà présent dans Wallet. Renvoie false s'il est absent.
    static func replaceInWallet(with pass: PKPass) -> Bool {
        library.containsPass(pass) && library.replacePass(with: pass)
    }

    static func removeFromWallet(_ pass: PKPass) {
        if let existing = installedPass(matching: pass) {
            library.removePass(existing)
        }
    }
}

/// Signature des pass en arrière-plan : l'import du certificat (.p12) et la signature RSA prennent
/// plusieurs dizaines de millisecondes, qui ne doivent pas retarder l'affichage au lancement.
actor PassSigner {
    static let shared = PassSigner()
    private var identity: PassSigningIdentity?

    func pkpass(for badge: BadgeData, images: [String: Data], branding: PassBranding) throws -> Data {
        let identity = try self.identity ?? loadIdentity()
        self.identity = identity
        return try PassBuilder.pkpass(for: badge, identity: identity, images: images, branding: branding)
    }

    /// Lit PassCertificate.p12, son mot de passe (PassSigning.plist) et les certificats Apple WWDR (*.cer)
    /// embarqués dans l'application ; une seule fois, l'identité est ensuite gardée en mémoire.
    private func loadIdentity() throws -> PassSigningIdentity {
        let bundle = Bundle.main
        guard let certificateURL = bundle.url(forResource: "PassCertificate", withExtension: "p12") else {
            throw PassSigningError.missingCertificate
        }
        var password = ""
        if let settingsURL = bundle.url(forResource: "PassSigning", withExtension: "plist"),
           let settingsData = try? Data(contentsOf: settingsURL),
           let settings = try? PropertyListSerialization.propertyList(from: settingsData, format: nil) as? [String: Any],
           let value = settings["CertificatePassword"] as? String {
            password = value
        }
        let intermediates = (bundle.urls(forResourcesWithExtension: "cer", subdirectory: nil) ?? [])
            .compactMap { try? Data(contentsOf: $0) }
        return try PassSigningIdentity.load(
            pkcs12: try Data(contentsOf: certificateURL),
            password: password,
            intermediates: intermediates
        )
    }
}
