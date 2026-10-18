import Foundation
import XCTest
@testable import BadgeCore

final class CrecheDirectoryTests: XCTestCase {
    private func sample() throws -> CrecheDirectory {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "creches-sample", withExtension: "json", subdirectory: "Fixtures"))
        return try CrecheDirectory(data: Data(contentsOf: url))
    }

    func testNearestIsSortedByDistance() throws {
        // Rue Montmartre (1er) : la plus proche est rue Saint-Denis.
        let nearest = try sample().nearest(latitude: 48.8640, longitude: 2.3430, count: 3)
        XCTAssertEqual(nearest.map(\.creche.id), ["4", "3", "1"])
        XCTAssertEqual(nearest[0].distance, 549, accuracy: 5)
        XCTAssertTrue(zip(nearest, nearest.dropFirst()).allSatisfy { $0.distance <= $1.distance })
    }

    func testSearchIgnoresAccentsAndCase() throws {
        let directory = try sample()
        XCTAssertEqual(directory.search("perignon").map(\.id), ["5"])
        XCTAssertEqual(directory.search("AQUEDUC halte").map(\.id), ["3"])
        XCTAssertEqual(directory.search("16e").map(\.id), ["5"])
        XCTAssertEqual(directory.search("75019").map(\.id), ["1"])
        XCTAssertEqual(directory.search("  ").count, 5)
        // Ponctuation et pluriels tolérés.
        XCTAssertEqual(directory.search("saint-denis").map(\.id), ["4"])
        XCTAssertEqual(directory.search("lauzins").map(\.id), ["1"])
        XCTAssertEqual(directory.search("l'aqueduc haltes").map(\.id), ["3"])
        XCTAssertTrue(directory.search("introuvable").isEmpty)
    }

    func testArrondissementAndAddress() throws {
        let creches = try sample().creches
        XCTAssertEqual(creches[3].arrondissement, "1er arrondissement")
        XCTAssertEqual(creches[4].arrondissementNumber, 16)
        XCTAssertEqual(creches[0].subtitle, "Crèche municipale · 22 Rue Lauzin, 75019 Paris")
        XCTAssertEqual(creches[3].subtitle, "Crèche · 12 Rue Saint-Denis, 75001 Paris")
        let official = Creche(
            id: "pf-19903", name: "Crèche municipale Grange aux belles, Hôpital Saint-Louis", kind: "Crèche",
            management: "municipale", street: "16 Rue de la Grange aux Belles", postcode: "75010", lat: 48.8748, lon: 2.3667
        )
        XCTAssertEqual(official.subtitle, "16 Rue de la Grange aux Belles, 75010 Paris")
        let address = creches[0].badgeAddress
        XCTAssertEqual(address.name, "Crèche rue Lauzin")
        XCTAssertEqual(address.label, "22 Rue Lauzin, 75019 Paris")
    }

    func testOldBadgesWithoutCrecheNameStillDecode() throws {
        let json = #"{"label":"2 rue de Rivoli","latitude":48.85,"longitude":2.36}"#
        let address = try JSONDecoder().decode(CrecheAddress.self, from: Data(json.utf8))
        XCTAssertNil(address.name)
    }

    /// Contrôle de la liste réellement embarquée dans l'app.
    func testBundledParisList() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App/BadgeCreche/Resources/creches-paris.json")
        let directory = try CrecheDirectory(data: Data(contentsOf: url))
        XCTAssertGreaterThan(directory.creches.count, 800)
        XCTAssertEqual(Set(directory.creches.map(\.id)).count, directory.creches.count, "identifiants en double")
        XCTAssertEqual(Set(directory.creches.map(\.arrondissementNumber)), Set(1...20), "arrondissements manquants")
        for creche in directory.creches {
            XCTAssertTrue((48.80...48.91).contains(creche.lat) && (2.22...2.47).contains(creche.lon), creche.name)
            XCTAssertFalse(creche.name.isEmpty)
            XCTAssertFalse(creche.street.isEmpty, creche.name)
        }
        XCTAssertTrue(directory.licence.contains("ODbL"))
        // Crèche témoin signalée par un parent, cherchée comme il l'a écrite.
        let grange = directory.search("Granges aux belles")
        XCTAssertTrue(grange.contains { $0.postcode == "75010" && $0.name.contains("Grange aux belles") }, "\(grange.map(\.name))")
        print("Liste embarquée : \(directory.creches.count) établissements (\(directory.generated))")
    }
}
