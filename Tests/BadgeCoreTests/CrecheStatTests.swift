import Foundation
import XCTest
@testable import BadgeCore

final class CrecheStatTests: XCTestCase {
    private let endpoint = URL(string: "https://stats.example.org/matomo.php")!

    private func parameters(of stat: CrecheStat) throws -> [String: String] {
        let url = try XCTUnwrap(stat.trackingURL(endpoint: endpoint, siteID: 3))
        XCTAssertEqual(url.host, "stats.example.org")
        XCTAssertEqual(url.path, "/matomo.php")
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    func testEventDescribesTheChosenCreche() throws {
        let creche = Creche(
            id: "42", name: "Crèche Jardin & Cie + Lilas", kind: "Crèche", management: "municipale",
            street: "58 Rue Montmartre", postcode: "75002", lat: 48.866, lon: 2.345
        )
        let parameters = try parameters(of: CrecheStat(event: .created, source: .nearby, creche: creche))
        XCTAssertEqual(parameters["idsite"], "3")
        XCTAssertEqual(parameters["rec"], "1")
        XCTAssertEqual(parameters["e_c"], "Badge créé")
        XCTAssertEqual(parameters["e_a"], "Parmi les 3 plus proches")
        XCTAssertEqual(parameters["e_n"], "Crèche Jardin & Cie + Lilas · 75002")
    }

    func testOnlyTheEventIsSent() throws {
        let parameters = try parameters(of: CrecheStat(event: .crecheChanged, source: .manual, creche: nil))
        // Adresse hors liste jamais envoyée ; aucun identifiant ni position.
        XCTAssertEqual(parameters["e_n"], "Hors liste")
        XCTAssertEqual(
            Set(parameters.keys),
            ["idsite", "rec", "apiv", "send_image", "ca", "url", "e_c", "e_a", "e_n"]
        )
    }
}
