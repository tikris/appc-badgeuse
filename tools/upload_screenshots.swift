#!/usr/bin/env swift
// Envoie les captures de AppStore/captures/ sur App Store Connect (iPhone 6,9").
//
// Usage :
//   export ASC_KEY_ID=XXXXXXXXXX
//   export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
//   export ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8
//   swift tools/upload_screenshots.swift [dossier] [locale]
//
// Par défaut : dossier AppStore/captures, locale fr-FR. Les captures déjà
// présentes dans l'emplacement iPhone 6,9" de cette langue sont remplacées.

import CryptoKit
import Foundation

let bundleID = "fr.parentsapariscentre.badgecreche"
let displayType = "APP_IPHONE_67" // emplacement « iPhone 6,9" » (1320 × 2868)
let editableStates: Set<String> = [
    "PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY",
]

let args = CommandLine.arguments
let folder = URL(fileURLWithPath: args.count > 1 ? args[1] : "AppStore/captures")
let locale = args.count > 2 ? args[2] : "fr-FR"

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("Erreur : \(message)\n".utf8))
    exit(1)
}

func env(_ name: String) -> String {
    guard let value = ProcessInfo.processInfo.environment[name], !value.isEmpty else {
        fail("variable \(name) manquante")
    }
    return value
}

// MARK: - Jeton JWT (ES256, valable 20 min)

func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

func makeToken() throws -> String {
    let keyPath = (env("ASC_KEY_PATH") as NSString).expandingTildeInPath
    let pem = try String(contentsOfFile: keyPath, encoding: .utf8)
    let key = try P256.Signing.PrivateKey(pemRepresentation: pem)
    let now = Int(Date().timeIntervalSince1970)
    let header = try JSONSerialization.data(withJSONObject: ["alg": "ES256", "kid": env("ASC_KEY_ID"), "typ": "JWT"])
    let payload = try JSONSerialization.data(withJSONObject: [
        "iss": env("ASC_ISSUER_ID"), "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1",
    ])
    let signingInput = base64URL(header) + "." + base64URL(payload)
    let signature = try key.signature(for: Data(signingInput.utf8))
    return signingInput + "." + base64URL(signature.rawRepresentation)
}

// MARK: - Appels à l'API

let token = try makeToken()
let api = "https://api.appstoreconnect.apple.com/v1/"

typealias JSON = [String: Any]

@discardableResult
func call(_ method: String, _ path: String, body: JSON? = nil) async throws -> JSON {
    var request = URLRequest(url: URL(string: path.hasPrefix("https") ? path : api + path)!)
    request.httpMethod = method
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    if let body {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
    }
    let (data, response) = try await URLSession.shared.data(for: request)
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard (200..<300).contains(status) else {
        fail("\(method) \(path) → HTTP \(status)\n\(String(decoding: data, as: UTF8.self))")
    }
    if data.isEmpty { return [:] }
    return (try JSONSerialization.jsonObject(with: data) as? JSON) ?? [:]
}

func items(_ json: JSON) -> [JSON] { json["data"] as? [JSON] ?? [] }
func attributes(_ item: JSON) -> JSON { item["attributes"] as? JSON ?? [:] }
func id(_ item: JSON) -> String { item["id"] as? String ?? "" }

// MARK: - App, version modifiable, langue

let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension.lowercased() == "png" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
guard !files.isEmpty else { fail("aucune image PNG dans \(folder.path)") }

guard let app = items(try await call("GET", "apps?filter[bundleId]=\(bundleID)")).first else {
    fail("aucune app « \(bundleID) » sur App Store Connect")
}
print("App : \(attributes(app)["name"] ?? bundleID)")

let versions = items(try await call("GET", "apps/\(id(app))/appStoreVersions?filter[platform]=IOS&limit=20"))
guard let version = versions.first(where: { editableStates.contains(attributes($0)["appStoreState"] as? String ?? "") }) else {
    fail("aucune version iOS modifiable (créez une version « Prête à être soumise » dans App Store Connect)")
}
print("Version : \(attributes(version)["versionString"] ?? "?")")

let localizations = items(try await call("GET", "appStoreVersions/\(id(version))/appStoreVersionLocalizations"))
guard let localization = localizations.first(where: { attributes($0)["locale"] as? String == locale }) else {
    let available = localizations.compactMap { attributes($0)["locale"] as? String }.joined(separator: ", ")
    fail("langue \(locale) absente de la version (disponibles : \(available))")
}

// MARK: - Emplacement iPhone 6,9" (créé au besoin, vidé sinon)

let sets = items(try await call("GET", "appStoreVersionLocalizations/\(id(localization))/appScreenshotSets"))
let screenshotSetID: String
if let existing = sets.first(where: { attributes($0)["screenshotDisplayType"] as? String == displayType }) {
    screenshotSetID = id(existing)
    for old in items(try await call("GET", "appScreenshotSets/\(screenshotSetID)/appScreenshots")) {
        try await call("DELETE", "appScreenshots/\(id(old))")
        print("Supprimée : \(attributes(old)["fileName"] ?? id(old))")
    }
} else {
    let created = try await call("POST", "appScreenshotSets", body: ["data": [
        "type": "appScreenshotSets",
        "attributes": ["screenshotDisplayType": displayType],
        "relationships": ["appStoreVersionLocalization": ["data": ["type": "appStoreVersionLocalizations", "id": id(localization)]]],
    ]])
    screenshotSetID = id(created["data"] as? JSON ?? [:])
}

// MARK: - Envoi : réservation, dépôt des morceaux, validation

var uploadedIDs: [String] = []
for file in files {
    let data = try Data(contentsOf: file)
    let reservation = try await call("POST", "appScreenshots", body: ["data": [
        "type": "appScreenshots",
        "attributes": ["fileName": file.lastPathComponent, "fileSize": data.count],
        "relationships": ["appScreenshotSet": ["data": ["type": "appScreenshotSets", "id": screenshotSetID]]],
    ]])
    let screenshot = reservation["data"] as? JSON ?? [:]
    let operations = attributes(screenshot)["uploadOperations"] as? [JSON] ?? []

    for operation in operations {
        guard let urlString = operation["url"] as? String, let url = URL(string: urlString),
              let offset = operation["offset"] as? Int, let length = operation["length"] as? Int else { continue }
        var request = URLRequest(url: url)
        request.httpMethod = operation["method"] as? String ?? "PUT"
        for header in operation["requestHeaders"] as? [JSON] ?? [] {
            if let name = header["name"] as? String, let value = header["value"] as? String {
                request.setValue(value, forHTTPHeaderField: name)
            }
        }
        let (_, response) = try await URLSession.shared.upload(for: request, from: data.subdata(in: offset..<offset + length))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { fail("dépôt de \(file.lastPathComponent) → HTTP \(status)") }
    }

    let checksum = Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
    try await call("PATCH", "appScreenshots/\(id(screenshot))", body: ["data": [
        "type": "appScreenshots", "id": id(screenshot),
        "attributes": ["uploaded": true, "sourceFileChecksum": checksum],
    ]])
    uploadedIDs.append(id(screenshot))
    print("Envoyée : \(file.lastPathComponent)")
}

// Ordre d'affichage = ordre alphabétique des fichiers (01-…, 02-…).
try await call("PATCH", "appScreenshotSets/\(screenshotSetID)/relationships/appScreenshots", body: [
    "data": uploadedIDs.map { ["type": "appScreenshots", "id": $0] },
])
print("Terminé : \(uploadedIDs.count) captures dans iPhone 6,9\" (\(locale)). App Store Connect les traite en quelques minutes.")
