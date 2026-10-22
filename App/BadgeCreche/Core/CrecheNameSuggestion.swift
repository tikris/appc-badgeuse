import Foundation

/// Nom d'usage proposé par un parent pour une crèche de la liste (ou crèche absente de la liste),
/// envoyé depuis sa propre messagerie : l'APPC le reporte dans tools/creches-noms.csv et la liste
/// corrigée profite à tous les parents dans la version suivante. Aucun serveur ni base de données.
nonisolated struct CrecheNameSuggestion: Equatable {
    let proposedName: String
    /// Nom affiché aujourd'hui dans l'application.
    let currentName: String?
    let address: String
    /// Référence dans la liste embarquée ; nil pour une crèche absente de la liste.
    let crecheID: String?

    init(proposedName: String, currentName: String?, address: String, crecheID: String?) {
        self.proposedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.currentName = currentName
        self.address = address
        self.crecheID = crecheID
    }

    /// Un nom non vide et différent de celui déjà affiché.
    var isValid: Bool {
        !proposedName.isEmpty
            && CrecheDirectory.fold(proposedName) != CrecheDirectory.fold(currentName ?? "")
    }

    var subject: String {
        crecheID == nil ? "Badge Crèche : crèche absente de la liste" : "Badge Crèche : nom d'usage d'une crèche"
    }

    var body: String {
        var lines = ["Nom proposé : \(proposedName)"]
        if let currentName {
            lines.append("Nom dans l'application : \(currentName)")
        }
        lines.append("Adresse : \(address)")
        lines.append("Référence : \(crecheID ?? "absente de la liste")")
        lines.append("")
        lines.append("Envoyé depuis l'application Badge Crèche. Rien d'autre n'est joint : ni QR code, ni nom d'enfant, ni position.")
        return lines.joined(separator: "\n")
    }

    /// E-mail prêt à envoyer. Objet et texte entièrement encodés (« & » d'un nom comme « People & Baby » compris).
    func mailtoURL(to recipient: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.percentEncodedQuery = "subject=\(Self.encode(subject))&body=\(Self.encode(body))"
        return components.url
    }

    private static func encode(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }

    /// Caractères non réservés (RFC 3986) : tout le reste est encodé.
    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )
}
