import Foundation
import Security

nonisolated enum PassSigningError: LocalizedError {
    case missingCertificate
    case wrongPassword
    case pkcs12ImportFailed(OSStatus)
    case noIdentity
    case notAPassCertificate
    case missingIntermediate
    case intermediateMismatch
    case signatureFailed

    var errorDescription: String? {
        switch self {
        case .missingCertificate:
            "Certificat de signature introuvable dans l'application (PassCertificate.p12). Voir le README, section « Certificat Wallet »."
        case .wrongPassword:
            "Mot de passe du certificat incorrect (PassSigning.plist)."
        case .pkcs12ImportFailed(let status):
            "Impossible de lire le certificat de signature (code \(status))."
        case .noIdentity:
            "Le fichier PassCertificate.p12 ne contient pas de clé privée."
        case .notAPassCertificate:
            "Le certificat fourni n'est pas un certificat « Pass Type ID » Apple."
        case .missingIntermediate:
            "Certificat intermédiaire Apple WWDR introuvable (AppleWWDRCAG4.cer)."
        case .intermediateMismatch:
            "Le certificat intermédiaire WWDR ne correspond pas au certificat du pass (téléchargez la bonne génération, ex. G4)."
        case .signatureFailed:
            "La signature du pass a échoué."
        }
    }
}

/// Certificat « Pass Type ID » + clé privée servant à signer les pass Wallet.
nonisolated struct PassSigningIdentity {
    let certificate: [UInt8]
    let chain: [[UInt8]]
    let privateKey: SecKey
    /// Lu dans le certificat (attribut UID), ex. `pass.fr.parentsapariscentre.badge`.
    let passTypeIdentifier: String
    /// Lu dans le certificat (attribut OU), ex. `ABCDE12345`.
    let teamIdentifier: String

    init(certificate: Data, intermediate: Data, privateKey: SecKey) throws {
        let info = try CertificateInfo(der: Array(certificate))
        guard let passType = info.subjectValue(for: OID.userID), passType.hasPrefix("pass."),
              let team = info.subjectValue(for: OID.organizationalUnit) else {
            throw PassSigningError.notAPassCertificate
        }
        guard try CertificateInfo(der: Array(intermediate)).subject == info.issuer else {
            throw PassSigningError.intermediateMismatch
        }
        self.certificate = Array(certificate)
        self.chain = [Array(intermediate)]
        self.privateKey = privateKey
        self.passTypeIdentifier = passType
        self.teamIdentifier = team
    }

    /// Charge l'identité depuis un .p12 exporté du Trousseau d'accès.
    /// `intermediates` : certificats Apple WWDR candidats (le bon est choisi d'après l'émetteur) ;
    /// à défaut, le certificat intermédiaire est cherché dans le .p12 lui-même.
    static func load(pkcs12: Data, password: String, intermediates: [Data]) throws -> PassSigningIdentity {
        var items: CFArray?
        let options = [kSecImportExportPassphrase as String: password] as CFDictionary
        let status = SecPKCS12Import(pkcs12 as CFData, options, &items)
        guard status == errSecSuccess else {
            throw status == errSecAuthFailed ? PassSigningError.wrongPassword : PassSigningError.pkcs12ImportFailed(status)
        }
        guard let first = (items as? [[String: Any]])?.first,
              let identityValue = first[kSecImportItemIdentity as String] else {
            throw PassSigningError.noIdentity
        }
        let identity = identityValue as! SecIdentity

        var certificateRef: SecCertificate?
        var keyRef: SecKey?
        guard SecIdentityCopyCertificate(identity, &certificateRef) == errSecSuccess, let certificateRef,
              SecIdentityCopyPrivateKey(identity, &keyRef) == errSecSuccess, let keyRef else {
            throw PassSigningError.noIdentity
        }
        let certificate = SecCertificateCopyData(certificateRef) as Data

        var candidates = intermediates
        if let chain = first[kSecImportItemCertChain as String] as? [SecCertificate] {
            candidates += chain.map { SecCertificateCopyData($0) as Data }
        }
        let issuer = try CertificateInfo(der: Array(certificate)).issuer
        guard let intermediate = candidates.first(where: { (try? CertificateInfo(der: Array($0)).subject) == issuer }) else {
            throw intermediates.isEmpty ? PassSigningError.missingIntermediate : PassSigningError.intermediateMismatch
        }
        return try PassSigningIdentity(certificate: certificate, intermediate: intermediate, privateKey: keyRef)
    }

    func sign(_ message: [UInt8]) throws -> [UInt8] {
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey, .rsaSignatureMessagePKCS1v15SHA256, Data(message) as CFData, &error
        ) as Data? else {
            if let error = error?.takeRetainedValue() { throw error as Error }
            throw PassSigningError.signatureFailed
        }
        return Array(signature)
    }
}
