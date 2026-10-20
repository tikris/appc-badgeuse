import Foundation

/// Un établissement d'accueil du jeune enfant de Paris (liste embarquée, voir tools/fetch_creches.py).
nonisolated struct Creche: Codable, Hashable, Identifiable {
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

nonisolated struct NearbyCreche: Hashable {
    let creche: Creche
    /// En mètres.
    let distance: Double
}

/// Liste des crèches, consultée entièrement sur l'appareil : la position ne quitte jamais l'iPhone.
nonisolated struct CrecheDirectory {
    let creches: [Creche]
    let source: String
    let licence: String
    let generated: String
    private let searchKeys: [String]

    private nonisolated struct Document: Decodable {
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

    /// Les `count` plus proches, en un seul passage sur la liste (sans la trier entièrement).
    func nearest(latitude: Double, longitude: Double, count: Int = 3) -> [NearbyCreche] {
        var best: [NearbyCreche] = []
        best.reserveCapacity(count + 1)
        for creche in creches {
            let distance = Self.distance(latitude, longitude, creche.lat, creche.lon)
            guard best.count < count || distance < best[best.count - 1].distance else { continue }
            let index = best.firstIndex { distance < $0.distance } ?? best.count
            best.insert(NearbyCreche(creche: creche, distance: distance), at: index)
            if best.count > count { best.removeLast() }
        }
        return best
    }

    /// Regroupement par arrondissement (1er, 2e…), dans l'ordre de la liste à l'intérieur de chaque groupe.
    static func byArrondissement(_ creches: [Creche]) -> [(title: String, creches: [Creche])] {
        Dictionary(grouping: creches, by: \.arrondissementNumber)
            .sorted { $0.key < $1.key }
            .map { (title: $0.value[0].arrondissement, creches: $0.value) }
    }

    /// Recherche sans accents, majuscules ni ponctuation ; chaque mot doit apparaître (nom, rue,
    /// code postal, arrondissement). Un pluriel est toléré : « granges » trouve « Grange aux Belles ».
    /// Les mots de catégorie ou de liaison sont facultatifs, car le nom officiel ne reprend pas toujours
    /// le nom d'usage : « halte garderie Montmartre » trouve aussi « Crèche rue Montmartre ».
    /// Les crèches qui contiennent tous les mots passent en premier.
    func search(_ query: String) -> [Creche] {
        let terms = Self.fold(query).split(separator: " ").map(String.init)
        guard !terms.isEmpty else { return creches }
        let significant = terms.filter { !Self.optionalTerms.contains($0) }
        let required = significant.isEmpty ? terms : significant
        var complete: [Creche] = []
        var partial: [Creche] = []
        for (creche, key) in zip(creches, searchKeys) where required.allSatisfy({ Self.key(key, contains: $0) }) {
            if terms.allSatisfy({ Self.key(key, contains: $0) }) {
                complete.append(creche)
            } else {
                partial.append(creche)
            }
        }
        return complete + partial
    }

    /// Mots qui n'écartent jamais une crèche à eux seuls (sauf s'ils sont seuls dans la recherche).
    private static let optionalTerms: Set<String> = [
        "creche", "creches", "halte", "haltes", "garderie", "garderies", "multi", "accueil", "micro",
        "jardin", "jardins", "enfant", "enfants", "municipale", "municipal", "associative", "associatif",
        "parentale", "familiale", "collective", "de", "du", "des", "d", "la", "le", "les", "l", "aux", "au", "et",
    ]

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
