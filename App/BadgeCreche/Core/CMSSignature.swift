import CryptoKit
import Foundation

/// Signature PKCS#7 / CMS détachée du manifest d'un pass Wallet.
///
/// Structure produite (RFC 5652) :
/// ContentInfo { signedData, SignedData { v1, {sha256}, {data}, [0] certificats,
///   { SignerInfo { v1, émetteur+n° de série, sha256, [0] attributs signés,
///     rsaEncryption, signature } } } }
enum CMSSignature {
    static func detached(
        content: Data,
        certificate: [UInt8],
        chain: [[UInt8]],
        signingTime: Date,
        sign: ([UInt8]) throws -> [UInt8]
    ) throws -> Data {
        let signer = try CertificateInfo(der: certificate)
        let digest = Array(SHA256.hash(data: content))
        let sha256 = DER.sequence([DER.oid(OID.sha256)])

        let signedAttributes = DER.set([
            DER.sequence([DER.oid(OID.contentType), DER.set([DER.oid(OID.data)])]),
            DER.sequence([DER.oid(OID.signingTime), DER.set([DER.utcTime(signingTime)])]),
            DER.sequence([DER.oid(OID.messageDigest), DER.set([DER.octetString(digest)])]),
        ])
        // La signature porte sur l'encodage SET (0x31) des attributs…
        let signature = try sign(signedAttributes)
        // …qui sont ensuite stockés avec la balise implicite [0].
        var implicitAttributes = signedAttributes
        implicitAttributes[0] = 0xA0

        let signerInfo = DER.sequence([
            DER.integer(1),
            DER.sequence([signer.issuer, signer.serialNumber]),
            sha256,
            implicitAttributes,
            DER.sequence([DER.oid(OID.rsaEncryption), DER.null]),
            DER.octetString(signature),
        ])

        let signedData = DER.sequence([
            DER.integer(1),
            DER.set([sha256]),
            DER.sequence([DER.oid(OID.data)]),
            DER.context(0, ([certificate] + chain).flatMap { $0 }),
            DER.set([signerInfo]),
        ])

        return Data(DER.sequence([DER.oid(OID.signedData), DER.context(0, signedData)]))
    }
}
