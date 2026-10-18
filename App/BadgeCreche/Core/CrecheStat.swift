import Foundation

/// Statistique facultative (désactivée par défaut) envoyée au Matomo de l'APPC, uniquement avec
/// l'accord du parent : la crèche choisie et la façon dont elle l'a été. Ni QR code, ni nom d'enfant,
/// ni position, ni identifiant de visiteur ; l'adresse d'une crèche hors liste n'est jamais envoyée.
nonisolated struct CrecheStat: Equatable {
    nonisolated enum Event: String {
        case created = "Badge créé"
        case crecheChanged = "Crèche changée"
    }

    nonisolated enum Source: String {
        case nearby = "Parmi les 3 plus proches"
        case list = "Dans la liste"
        case manual = "Hors liste"
    }

    let event: Event
    let source: Source
    /// « Nom · code postal » pour une crèche de la liste, « Hors liste » sinon.
    let crecheLabel: String

    init(event: Event, source: Source, creche: Creche?) {
        self.event = event
        self.source = source
        crecheLabel = creche.map { "\($0.name) · \($0.postcode)" } ?? Source.manual.rawValue
    }

    /// Requête de l'API HTTP de suivi Matomo (adresse en …/matomo.php), sous forme d'événement.
    func trackingURL(endpoint: URL, siteID: Int) -> URL? {
        let parameters = [
            ("idsite", String(siteID)),
            ("rec", "1"),
            ("apiv", "1"),
            ("send_image", "0"),
            ("ca", "1"),
            ("url", "http://fr.parentsapariscentre.badgecreche/badge"),
            ("e_c", event.rawValue),
            ("e_a", source.rawValue),
            ("e_n", crecheLabel),
        ]
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.percentEncodedQuery = parameters
            .map { "\($0)=\($1.addingPercentEncoding(withAllowedCharacters: Self.unreserved) ?? "")" }
            .joined(separator: "&")
        return components?.url
    }

    /// Caractères non réservés (RFC 3986) : tout le reste est encodé, y compris « & », « + » et les accents.
    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )
}
