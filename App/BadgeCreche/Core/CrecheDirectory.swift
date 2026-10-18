import Foundation

/// Un établissement d'accueil du jeune enfant de Paris (liste embarquée, voir tools/fetch_creches.py).
struct Creche: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let kind: String
    let management: String?
    let street: String
    let postcode: String
    let lat: Double
    let lon: Double

    var fullAddress: String {
        postcode.isEmpty ? "\(street), Paris" : "\(street), \(postcode) Paris"
    }

    /// 1 à 20 (75116 compte pour le 16e), 0 si inconnu.
    var arrondissementNumber: Int {
        guard postcode.hasPrefix("75"), let number = Int(postcode.suffix(3)) else { return 0 }
        return number == 116 ? 16 : number
    }

    var arrondissement: String {
        switch arrondissementNumber {
        case 0: "Paris"
        case 1: "1er arrondissement"
        default: "\(arrondissementNumber)e arrondissement"
        }
    }

    /// Ex. « Crèche municipale · 22 Rue Lauzin, 75019 Paris » ; l'adresse seule quand le nom
    /// commence déjà par la catégorie (« Crèche municipale Grange aux belles »).
    var subtitle: String {
        let category = [kind, management].compactMap { $0 }.joined(separator: " ")
        if management != nil, CrecheDirectory.fold(name).hasPrefix(CrecheDirectory.fold(category)) {
            return fullAddress
        }
        return "\(category) · \(fullAddress)"
    }

    var badgeAddress: CrecheAddress {
        CrecheAddress(label: fullAddress, latitude: lat, longitude: lon, name: name)
    }
}

struct NearbyCreche: Hashable {
    let creche: Creche
    /// En mètres.
    let distance: Double
}

/// Liste des crèches, consultée entièrement sur l'appareil : la position ne quitte jamais l'iPhone.
struct CrecheDirectory {
    let creches: [Creche]
    let source: String
    let licence: String
    let generated: String
    private let searchKeys: [String]

    private struct Document: Decodable {
        let source: String
        let licence: String
        let generated: String
        let creches: [Creche]
    }

    init(data: Data) throws {
        let document = try JSONDecoder().decode(Document.self, from: data)
        creches = document.creches
        source = document.source
        licence = document.licence
        generated = document.generated
        searchKeys = document.creches.map { creche in
            Self.fold("\(creche.name) \(creche.street) \(creche.postcode) \(creche.arrondissement) \(creche.kind)")
        }
    }

    func nearest(latitude: Double, longitude: Double, count: Int = 3) -> [NearbyCreche] {
        let sorted = creches
            .map { NearbyCreche(creche: $0, distance: Self.distance(latitude, longitude, $0.lat, $0.lon)) }
            .sorted { $0.distance < $1.distance }
        return Array(sorted.prefix(count))
    }

    /// Recherche sans accents, majuscules ni ponctuation ; chaque mot doit apparaître (nom, rue,
    /// code postal, arrondissement). Un pluriel est toléré : « granges » trouve « Grange aux Belles ».
    func search(_ query: String) -> [Creche] {
        let terms = Self.fold(query).split(separator: " ").map(String.init)
        guard !terms.isEmpty else { return creches }
        return zip(creches, searchKeys)
            .filter { _, key in terms.allSatisfy { Self.key(key, contains: $0) } }
            .map(\.0)
    }

    private static func key(_ key: String, contains term: String) -> Bool {
        if key.contains(term) { return true }
        guard term.count > 3, let last = term.last, last == "s" || last == "x" else { return false }
        return key.contains(term.dropLast())
    }

    /// Minuscules sans accents ; tirets, apostrophes et ponctuation deviennent des espaces.
    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: "[-'’,.()&/]", with: " ", options: .regularExpression)
    }

    /// Distance à vol d'oiseau (formule de haversine), en mètres.
    static func distance(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let radius = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * radius * atan2(sqrt(a), sqrt(1 - a))
    }
}
