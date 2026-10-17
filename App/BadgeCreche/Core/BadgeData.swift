import Foundation

/// Adresse de la crèche et coordonnées utilisées par Wallet pour afficher le badge à proximité.
struct CrecheAddress: Codable, Hashable {
    var label: String
    var latitude: Double
    var longitude: Double
    /// Nom de l'établissement (liste des crèches ou Apple Plans), même s'il n'est pas affiché sur le badge.
    var name: String? = nil
}

/// Le badge enregistré localement. Version 1 : un seul badge par iPhone.
struct BadgeData: Codable, Hashable {
    /// Identifiant stable du pass dans Wallet (permet de le mettre à jour plutôt que d'en créer un second).
    var serialNumber: String
    /// Contenu exact du QR code remis par la crèche.
    var qrPayload: String
    var showsChildName: Bool
    var childFirstName: String
    var childLastName: String
    var crecheName: String
    var address: CrecheAddress
    var updatedAt: Date

    /// Nom affiché sur le pass, uniquement si le parent l'a choisi.
    var displayedChildName: String? {
        guard showsChildName else { return nil }
        let name = [childFirstName, childLastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? nil : name
    }

    var displayedCrecheName: String? {
        let name = crecheName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    /// Encodage du QR code : ISO-8859-1 (valeur recommandée par Apple) quand le contenu est en ASCII,
    /// ce qui reproduit les mêmes octets que l'original ; UTF-8 sinon.
    static func messageEncoding(for payload: String) -> String {
        payload.allSatisfy(\.isASCII) ? "iso-8859-1" : "utf-8"
    }
}
