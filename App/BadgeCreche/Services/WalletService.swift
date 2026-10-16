import Foundation
import PassKit

/// Création du pass signé et dialogue avec Apple Wallet.
///
/// Les opérations « est-il déjà dans Wallet ? / remplacer / supprimer » nécessitent la
/// capacité Wallet (entitlement) avec le Pass Type ID dans Xcode. Sans elle, l'ajout
/// fonctionne mais l'application ne voit pas le pass déjà présent.
@MainActor
enum WalletService {
    private static var cachedIdentity: PassSigningIdentity?
    private static let library = PKPassLibrary()

    static let isAvailable = PKPassLibrary.isPassLibraryAvailable() && PKAddPassesViewController.canAddPasses()

    static func makePass(for badge: BadgeData) throws -> PKPass {
        let data = try PassBuilder.pkpass(
            for: badge,
            identity: try signingIdentity(),
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

    /// Lit PassCertificate.p12, son mot de passe (PassSigning.plist) et les certificats Apple WWDR (*.cer)
    /// embarqués dans l'application.
    private static func signingIdentity() throws -> PassSigningIdentity {
        if let cachedIdentity { return cachedIdentity }
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
        let identity = try PassSigningIdentity.load(
            pkcs12: try Data(contentsOf: certificateURL),
            password: password,
            intermediates: intermediates
        )
        cachedIdentity = identity
        return identity
    }
}
