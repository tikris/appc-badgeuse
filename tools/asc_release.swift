#!/usr/bin/env swift
// Prépare la version App Store sur App Store Connect : attend la fin du traitement du build,
// l'associe à la version en cours, remplace les notes pour l'App Review (AppStore/review-notes.txt)
// et joint le QR code de démonstration (docs/demo-qr.png) ainsi que les fichiers demandés.
// La soumission elle-même reste un clic dans App Store Connect, après avoir joint la vidéo.
//
// Usage :
//   export ASC_KEY_ID=XXXXXXXXXX
//   export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
//   export ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8
//   swift tools/asc_release.swift <numéro de build> [--attach fichier]…
//
// Exemple : swift tools/asc_release.swift 5 --attach ~/Desktop/demo.mov

import CryptoKit
import Foundation

let bundleID = "fr.parentsapariscentre.badgecreche"
let editableStates: Set<String> = [
    "PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY",
]
let notesFile = URL(fileURLWithPath: "AppStore/review-notes.txt")
var attachments = [URL(fileURLWithPath: "docs/demo-qr.png")]

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("Erreur : \(message)\n".utf8))
    exit(1)
}

var arguments = Array(CommandLine.arguments.dropFirst())
guard let buildNumber = arguments.first, !buildNumber.hasPrefix("-") else {
    fail("numéro de build manquant (ex. swift tools/asc_release.swift 5)")
}
arguments.removeFirst()
while !arguments.isEmpty {
    let option = arguments.removeFirst()
    guard option == "--attach", !arguments.isEmpty else { fail("option inconnue : \(option)") }
    attachments.append(URL(fileURLWithPath: (arguments.removeFirst() as NSString).expandingTildeInPath))
}

func env(_ name: String) -> String {
    guard let value = ProcessInfo.processInfo.environment[name], !value.isEmpty else {
        fail("variable \(name) manquante")
    }
    return value
}

// MARK: - Jeton JWT (ES256), renouvelé à chaque appel : l'attente du build peut durer

func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

let privateKey: P256.Signing.PrivateKey = {
    let keyPath = (env("ASC_KEY_PATH") as NSString).expandingTildeInPath
    guard let pem = try? String(contentsOfFile: keyPath, encoding: .utf8),
          let key = try? P256.Signing.PrivateKey(pemRepresentation: pem) else {
        fail("clé API illisible : \(keyPath)")
    }
    return key
}()

func makeToken() throws -> String {
    let now = Int(Date().timeIntervalSince1970)
    let header = try JSONSerialization.data(withJSONObject: ["alg": "ES256", "kid": env("ASC_KEY_ID"), "typ": "JWT"])
    let payload = try JSONSerialization.data(withJSONObject: [
        "iss": env("ASC_ISSUER_ID"), "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1",
    ])
    let signingInput = base64URL(header) + "." + base64URL(payload)
    let signature = try privateKey.signature(for: Data(signingInput.utf8))
    return signingInput + "." + base64URL(signature.rawRepresentation)
}

// MARK: - Appels à l'API

let api = "https://api.appstoreconnect.apple.com/v1/"

typealias JSON = [String: Any]

@discardableResult
func call(_ method: String, _ path: String, body: JSON? = nil) async throws -> JSON {
    var request = URLRequest(url: URL(string: path.hasPrefix("https") ? path : api + path)!)
    request.httpMethod = method
    request.setValue("Bearer \(try makeToken())", forHTTPHeaderField: "Authorization")
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
func item(_ json: JSON) -> JSON? { json["data"] as? JSON }
func attributes(_ item: JSON) -> JSON { item["attributes"] as? JSON ?? [:] }
func id(_ item: JSON) -> String { item["id"] as? String ?? "" }

// MARK: - App et version modifiable

guard let notes = try? String(contentsOf: notesFile, encoding: .utf8) else { fail("notes absentes : \(notesFile.path)") }
guard notes.count <= 4000 else { fail("notes App Review trop longues (\(notes.count) caractères, 4 000 au plus)") }

guard let app = items(try await call("GET", "apps?filter[bundleId]=\(bundleID)")).first else {
    fail("aucune app « \(bundleID) » sur App Store Connect")
}
let versions = items(try await call("GET", "apps/\(id(app))/appStoreVersions?filter[platform]=IOS&limit=20"))
guard let version = versions.first(where: { editableStates.contains(attributes($0)["appStoreState"] as? String ?? "") }) else {
    let states = versions.map { "\(attributes($0)["versionString"] ?? "?") : \(attributes($0)["appStoreState"] ?? "?")" }
    fail("aucune version iOS modifiable (\(states.joined(separator: ", ")))")
}
let versionString = attributes(version)["versionString"] as? String ?? "?"
print("Version \(versionString) (\(attributes(version)["appStoreState"] ?? "?"))")

// MARK: - Build : attente de la fin du traitement par Apple (jusqu'à 60 min)

var processedBuild: JSON?
for attempt in 0..<60 {
    let found = items(try await call(
        "GET", "builds?filter[app]=\(id(app))&filter[version]=\(buildNumber)&filter[preReleaseVersion.version]=\(versionString)&limit=1"
    )).first
    let state = found.map { attributes($0)["processingState"] as? String ?? "?" } ?? "pas encore reçu"
    if state == "VALID" { processedBuild = found; break }
    if state == "FAILED" || state == "INVALID" { fail("le build \(buildNumber) a été refusé par Apple (\(state))") }
    print("Build \(buildNumber) : \(state)… (\(attempt) min)")
    try await Task.sleep(for: .seconds(60))
}
guard let build = processedBuild else { fail("le build \(buildNumber) n'est toujours pas prêt après 60 minutes") }

try await call("PATCH", "appStoreVersions/\(id(version))/relationships/build", body: [
    "data": ["type": "builds", "id": id(build)],
])
print("Build \(buildNumber) associé à la version \(versionString)")

// MARK: - Notes pour l'App Review

let existingDetail = item(try await call("GET", "appStoreVersions/\(id(version))/appStoreReviewDetail"))
let detailID: String
if let existingDetail {
    detailID = id(existingDetail)
    try await call("PATCH", "appStoreReviewDetails/\(detailID)", body: ["data": [
        "type": "appStoreReviewDetails", "id": detailID,
        "attributes": ["notes": notes, "demoAccountRequired": false],
    ]])
} else {
    let created = try await call("POST", "appStoreReviewDetails", body: ["data": [
        "type": "appStoreReviewDetails",
        "attributes": ["notes": notes, "demoAccountRequired": false],
        "relationships": ["appStoreVersion": ["data": ["type": "appStoreVersions", "id": id(version)]]],
    ]])
    detailID = id(item(created) ?? [:])
}
print("Notes App Review mises à jour (\(notes.count) caractères)")

// MARK: - Pièces jointes (remplace celles du même nom)

let previous = items(try await call("GET", "appStoreReviewDetails/\(detailID)/appStoreReviewAttachments"))
for file in attachments {
    guard let data = try? Data(contentsOf: file) else { fail("pièce jointe illisible : \(file.path)") }
    for old in previous where attributes(old)["fileName"] as? String == file.lastPathComponent {
        try await call("DELETE", "appStoreReviewAttachments/\(id(old))")
    }
    let reservation = try await call("POST", "appStoreReviewAttachments", body: ["data": [
        "type": "appStoreReviewAttachments",
        "attributes": ["fileName": file.lastPathComponent, "fileSize": data.count],
        "relationships": ["appStoreReviewDetail": ["data": ["type": "appStoreReviewDetails", "id": detailID]]],
    ]])
    let attachment = item(reservation) ?? [:]
    for operation in attributes(attachment)["uploadOperations"] as? [JSON] ?? [] {
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
    try await call("PATCH", "appStoreReviewAttachments/\(id(attachment))", body: ["data": [
        "type": "appStoreReviewAttachments", "id": id(attachment),
        "attributes": ["uploaded": true, "sourceFileChecksum": checksum],
    ]])
    print("Pièce jointe envoyée : \(file.lastPathComponent)")
}

print("""
Prêt : version \(versionString), build \(buildNumber), notes et pièces jointes à jour.
Reste à faire dans App Store Connect : joindre la vidéo (si elle n'a pas été passée avec --attach),
répondre au message de l'App Review, puis « Soumettre pour vérification ».
""")
