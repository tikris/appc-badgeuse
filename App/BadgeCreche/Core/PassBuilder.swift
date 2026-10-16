import CryptoKit
import Foundation

/// Textes et couleurs du pass (fournis par AppConfig côté application).
struct PassBranding {
    var defaultTitle: String
    var backgroundColor: String
    var foregroundColor: String
    var labelColor: String
    var relevantText: String
    var usageText: String
    var aboutText: String
    var communityURL: String
    var communityLinkTitle: String
    var privacyText: String
}

/// Construit le fichier .pkpass signé, entièrement sur l'appareil.
enum PassBuilder {
    static func pkpass(
        for badge: BadgeData,
        identity: PassSigningIdentity,
        images: [String: Data],
        branding: PassBranding,
        now: Date = Date()
    ) throws -> Data {
        var files: [ZipArchive.Entry] = [
            ZipArchive.Entry(
                name: "pass.json",
                data: try passJSON(
                    for: badge,
                    passTypeIdentifier: identity.passTypeIdentifier,
                    teamIdentifier: identity.teamIdentifier,
                    branding: branding
                )
            ),
        ]
        for name in images.keys.sorted() {
            files.append(ZipArchive.Entry(name: name, data: images[name]!))
        }

        var manifest: [String: String] = [:]
        for file in files {
            manifest[file.name] = Insecure.SHA1.hash(data: file.data).map { String(format: "%02x", $0) }.joined()
        }
        let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys])
        let signature = try CMSSignature.detached(
            content: manifestData,
            certificate: identity.certificate,
            chain: identity.chain,
            signingTime: now,
            sign: identity.sign
        )
        files.append(ZipArchive.Entry(name: "manifest.json", data: manifestData))
        files.append(ZipArchive.Entry(name: "signature", data: signature))
        return ZipArchive.make(files, modifiedAt: now)
    }

    static func passJSON(
        for badge: BadgeData,
        passTypeIdentifier: String,
        teamIdentifier: String,
        branding: PassBranding
    ) throws -> Data {
        let childName = badge.displayedChildName
        let crecheName = badge.displayedCrecheName

        var primaryFields: [[String: Any]] = []
        var secondaryFields: [[String: Any]] = []
        if let childName {
            primaryFields.append(["key": "child", "label": "ENFANT", "value": childName])
            if let crecheName {
                secondaryFields.append(["key": "creche", "label": "CRÈCHE", "value": crecheName])
            }
        } else {
            primaryFields.append(["key": "creche", "label": "BADGE", "value": crecheName ?? branding.defaultTitle])
        }

        let backFields: [[String: Any]] = [
            ["key": "usage", "label": "Utilisation", "value": branding.usageText],
            ["key": "address", "label": "Adresse de la crèche", "value": badge.address.label],
            ["key": "about", "label": "À propos", "value": branding.aboutText],
            [
                "key": "community",
                "label": "Communauté",
                "value": "\(branding.communityLinkTitle) : \(branding.communityURL)",
                "attributedValue": "<a href=\"\(branding.communityURL)\">\(branding.communityLinkTitle)</a>",
            ],
            ["key": "privacy", "label": "Vos données", "value": branding.privacyText],
        ]

        var description = branding.defaultTitle
        if let childName { description += " – \(childName)" }

        let pass: [String: Any] = [
            "formatVersion": 1,
            "passTypeIdentifier": passTypeIdentifier,
            "teamIdentifier": teamIdentifier,
            "serialNumber": badge.serialNumber,
            "organizationName": crecheName ?? branding.defaultTitle,
            "description": description,
            "logoText": branding.defaultTitle,
            "backgroundColor": branding.backgroundColor,
            "foregroundColor": branding.foregroundColor,
            "labelColor": branding.labelColor,
            "barcodes": [[
                "format": "PKBarcodeFormatQR",
                "message": badge.qrPayload,
                "messageEncoding": BadgeData.messageEncoding(for: badge.qrPayload),
            ]],
            "locations": [
                [
                    "latitude": badge.address.latitude,
                    "longitude": badge.address.longitude,
                    "relevantText": branding.relevantText,
                ] as [String: Any],
            ],
            "generic": [
                "primaryFields": primaryFields,
                "secondaryFields": secondaryFields,
                "backFields": backFields,
            ] as [String: Any],
        ]
        return try JSONSerialization.data(withJSONObject: pass, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }
}
