import CryptoKit
import Foundation
import Security
import XCTest
@testable import BadgeCore

final class PassBuilderTests: XCTestCase {
    // MARK: Briques de base

    func testDEREncoding() {
        XCTAssertEqual(DER.oid(OID.signedData), [0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x07, 0x02])
        XCTAssertEqual(DER.oid(OID.userID), [0x06, 0x0A, 0x09, 0x92, 0x26, 0x89, 0x93, 0xF2, 0x2C, 0x64, 0x01, 0x01])
        XCTAssertEqual(DER.oid(OID.sha256), [0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01])
        XCTAssertEqual(DER.integer(1), [0x02, 0x01, 0x01])
        XCTAssertEqual(DER.integer(200), [0x02, 0x02, 0x00, 0xC8])
        XCTAssertEqual(DER.length(127), [0x7F])
        XCTAssertEqual(DER.length(200), [0x81, 0xC8])
        XCTAssertEqual(DER.length(1000), [0x82, 0x03, 0xE8])
        XCTAssertEqual(DER.utcTime(Date(timeIntervalSince1970: 0)), [0x17, 0x0D] + Array("700101000000Z".utf8))
    }

    func testCRC32() {
        XCTAssertEqual(CRC32.checksum(Data("123456789".utf8)), 0xCBF4_3926)
    }

    func testMessageEncoding() {
        XCTAssertEqual(BadgeData.messageEncoding(for: "ABC-123"), "iso-8859-1")
        XCTAssertEqual(BadgeData.messageEncoding(for: "Crèche"), "utf-8")
    }

    // MARK: Certificat

    func testIdentifiersAreReadFromCertificate() throws {
        let identity = try makeIdentity()
        XCTAssertEqual(identity.passTypeIdentifier, "pass.test.appc.badge")
        XCTAssertEqual(identity.teamIdentifier, "TEAM123456")
        XCTAssertEqual(identity.chain.count, 1)
    }

    func testWrongIntermediateIsRejected() throws {
        XCTAssertThrowsError(
            try PassSigningIdentity(
                certificate: fixture("test-pass-cert.der"),
                intermediate: fixture("test-root.der"),
                privateKey: privateKey()
            )
        )
    }

    func testIntermediateIsNotAPassCertificate() throws {
        XCTAssertThrowsError(
            try PassSigningIdentity(
                certificate: fixture("test-wwdr.der"),
                intermediate: fixture("test-root.der"),
                privateKey: privateKey()
            )
        )
    }

    // MARK: Pass complet

    func testPassIsSignedAndComplete() throws {
        let identity = try makeIdentity()
        let badge = Self.sampleBadge(showsChildName: true)
        let images = ["icon.png": Data([1, 2, 3]), "icon@2x.png": Data([4, 5, 6]), "logo.png": Data([7, 8])]
        let pkpass = try PassBuilder.pkpass(for: badge, identity: identity, images: images, branding: Self.branding)

        if let directory = ProcessInfo.processInfo.environment["BADGE_TEST_OUTPUT"] {
            let url = URL(fileURLWithPath: directory, isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try pkpass.write(to: url.appendingPathComponent("badge.pkpass"))
        }

        let entries = try unzipStored(pkpass)
        XCTAssertEqual(
            Set(entries.keys),
            ["pass.json", "icon.png", "icon@2x.png", "logo.png", "manifest.json", "signature"]
        )

        let manifestData = try XCTUnwrap(entries["manifest.json"])
        let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: manifestData) as? [String: String])
        XCTAssertEqual(Set(manifest.keys), ["pass.json", "icon.png", "icon@2x.png", "logo.png"])
        for (name, hash) in manifest {
            let data = try XCTUnwrap(entries[name])
            XCTAssertEqual(hash, Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined(), name)
        }

        let pass = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(entries["pass.json"])) as? [String: Any])
        XCTAssertEqual(pass["formatVersion"] as? Int, 1)
        XCTAssertEqual(pass["passTypeIdentifier"] as? String, "pass.test.appc.badge")
        XCTAssertEqual(pass["teamIdentifier"] as? String, "TEAM123456")
        XCTAssertEqual(pass["serialNumber"] as? String, badge.serialNumber)
        let barcode = try XCTUnwrap((pass["barcodes"] as? [[String: Any]])?.first)
        XCTAssertEqual(barcode["format"] as? String, "PKBarcodeFormatQR")
        XCTAssertEqual(barcode["message"] as? String, badge.qrPayload)
        XCTAssertEqual(barcode["messageEncoding"] as? String, "iso-8859-1")
        let location = try XCTUnwrap((pass["locations"] as? [[String: Any]])?.first)
        XCTAssertEqual(try XCTUnwrap(location["latitude"] as? Double), badge.address.latitude, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(location["longitude"] as? Double), badge.address.longitude, accuracy: 1e-9)
        XCTAssertEqual(pass["maxDistance"] as? Int, 20)
        let generic = try XCTUnwrap(pass["generic"] as? [String: Any])
        let primary = try XCTUnwrap((generic["primaryFields"] as? [[String: Any]])?.first)
        XCTAssertEqual(primary["value"] as? String, "Léa Martin")
        let backFields = try XCTUnwrap(generic["backFields"] as? [[String: Any]])
        XCTAssertTrue(backFields.contains { ($0["value"] as? String)?.contains("chat.whatsapp.com") == true })

        #if os(macOS)
        try verifyWithSecurityFramework(signature: XCTUnwrap(entries["signature"]), content: manifestData)
        #endif
    }

    func testChildNameIsHiddenWhenNotChosen() throws {
        let badge = Self.sampleBadge(showsChildName: false)
        let json = try PassBuilder.passJSON(
            for: badge, passTypeIdentifier: "pass.x", teamIdentifier: "T", branding: Self.branding
        )
        let text = String(decoding: json, as: UTF8.self)
        XCTAssertFalse(text.contains("Léa"))
        XCTAssertTrue(text.contains("Crèche des Lilas"))
    }

    // MARK: Outils

    static let branding = PassBranding(
        defaultTitle: "Badge crèche",
        backgroundColor: "rgb(34, 48, 90)",
        foregroundColor: "rgb(255, 255, 255)",
        labelColor: "rgb(255, 176, 150)",
        relevantText: "Vous arrivez à la crèche",
        usageText: "Présentez ce QR code à la badgeuse.",
        aboutText: "Une initiative de l'APPC.",
        communityURL: "https://chat.whatsapp.com/CiqGioqeO4yA93wTwvFJMW",
        communityLinkTitle: "Rejoindre la communauté WhatsApp de l'APPC",
        privacyText: "Aucune donnée n'est transmise à l'APPC."
    )

    static func sampleBadge(showsChildName: Bool) -> BadgeData {
        BadgeData(
            serialNumber: "TEST-SERIAL-0001",
            qrPayload: "APPC-DEMO-BADGE-0001",
            showsChildName: showsChildName,
            childFirstName: "Léa",
            childLastName: "Martin",
            crecheName: "Crèche des Lilas",
            address: CrecheAddress(label: "2 rue de Rivoli, 75004 Paris", latitude: 48.8556, longitude: 2.3600),
            updatedAt: Date(timeIntervalSince1970: 1_790_000_000)
        )
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    private func privateKey() throws -> SecKey {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
        ]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(try fixture("test-pass-key.der") as CFData, attributes as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        return key
    }

    private func makeIdentity() throws -> PassSigningIdentity {
        try PassSigningIdentity(
            certificate: fixture("test-pass-cert.der"),
            intermediate: fixture("test-wwdr.der"),
            privateKey: privateKey()
        )
    }

    /// Lecteur ZIP minimal (entrées non compressées), qui vérifie aussi les CRC.
    private func unzipStored(_ archive: Data) throws -> [String: Data] {
        let bytes = [UInt8](archive)
        func u16(_ at: Int) -> Int { Int(bytes[at]) | Int(bytes[at + 1]) << 8 }
        func u32(_ at: Int) -> Int { u16(at) | u16(at + 2) << 16 }
        var entries: [String: Data] = [:]
        var offset = 0
        while offset + 30 <= bytes.count, u32(offset) == 0x0403_4B50 {
            XCTAssertEqual(u16(offset + 8), 0, "entrée compressée inattendue")
            let crc = UInt32(u32(offset + 14))
            let size = u32(offset + 18)
            let nameLength = u16(offset + 26)
            let extraLength = u16(offset + 28)
            let nameStart = offset + 30
            let name = String(decoding: bytes[nameStart..<(nameStart + nameLength)], as: UTF8.self)
            let dataStart = nameStart + nameLength + extraLength
            let data = Data(bytes[dataStart..<(dataStart + size)])
            XCTAssertEqual(CRC32.checksum(data), crc, name)
            entries[name] = data
            offset = dataStart + size
        }
        XCTAssertEqual(u32(bytes.count - 22), 0x0605_4B50, "fin de répertoire central absente")
        return entries
    }

    #if os(macOS)
    /// Vérifie la signature CMS avec le framework Security d'Apple.
    private func verifyWithSecurityFramework(signature: Data, content: Data) throws {
        var decoderRef: CMSDecoder?
        XCTAssertEqual(CMSDecoderCreate(&decoderRef), errSecSuccess)
        let decoder = try XCTUnwrap(decoderRef)
        let updateStatus = signature.withUnsafeBytes { buffer in
            CMSDecoderUpdateMessage(decoder, buffer.baseAddress!, buffer.count)
        }
        XCTAssertEqual(updateStatus, errSecSuccess)
        XCTAssertEqual(CMSDecoderSetDetachedContent(decoder, content as CFData), errSecSuccess)
        XCTAssertEqual(CMSDecoderFinalizeMessage(decoder), errSecSuccess)
        var signerCount = 0
        XCTAssertEqual(CMSDecoderGetNumSigners(decoder, &signerCount), errSecSuccess)
        XCTAssertEqual(signerCount, 1)
        var status = CMSSignerStatus.unsigned
        var certificateResult: OSStatus = 0
        XCTAssertEqual(
            CMSDecoderCopySignerStatus(decoder, 0, SecPolicyCreateBasicX509(), false, &status, nil, &certificateResult),
            errSecSuccess
        )
        print("CMSSignerStatus =", status.rawValue, "certificat =", certificateResult)
        XCTAssertNotEqual(status, .invalidSignature)
        XCTAssertNotEqual(status, .needsDetachedContent)
        XCTAssertNotEqual(status, .unsigned)
    }
    #endif
}
