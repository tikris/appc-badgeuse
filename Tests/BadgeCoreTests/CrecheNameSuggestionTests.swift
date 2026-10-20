import Foundation
import XCTest
@testable import BadgeCore

final class CrecheNameSuggestionTests: XCTestCase {
    private let suggestion = CrecheNameSuggestion(
        proposedName: "  Babilou Dames & Batignolles ",
        currentName: "Crèche rue des Dames",
        address: "86 Rue des Dames, 75017 Paris",
        crecheID: "apur-753007001"
    )

    func testContentHasOnlyTheCrecheAndTheProposedName() {
        XCTAssertEqual(suggestion.proposedName, "Babilou Dames & Batignolles")
        XCTAssertEqual(suggestion.subject, "Badge Crèche : nom d'usage d'une crèche")
        XCTAssertTrue(suggestion.body.hasPrefix("Nom proposé : Babilou Dames & Batignolles\nNom dans l'application : Crèche rue des Dames\n"))
        XCTAssertTrue(suggestion.body.contains("Référence : apur-753007001"))
        let missing = CrecheNameSuggestion(proposedName: "Les Lucioles", currentName: nil, address: "3 Rue X, 75003 Paris", crecheID: nil)
        XCTAssertEqual(missing.subject, "Badge Crèche : crèche absente de la liste")
        XCTAssertTrue(missing.body.contains("Référence : absente de la liste"))
    }

    func testValidity() {
        XCTAssertTrue(suggestion.isValid)
        XCTAssertFalse(CrecheNameSuggestion(proposedName: "   ", currentName: "A", address: "", crecheID: "1").isValid)
        XCTAssertFalse(CrecheNameSuggestion(proposedName: "creche RUE des dames", currentName: "Crèche rue des Dames", address: "", crecheID: "1").isValid)
    }

    func testMailtoKeepsAmpersandsAndLineBreaks() throws {
        let url = try XCTUnwrap(suggestion.mailtoURL(to: "contact@appc.paris"))
        XCTAssertTrue(url.absoluteString.hasPrefix("mailto:contact@appc.paris?subject="))
        XCTAssertFalse(url.absoluteString.contains(" "))
        XCTAssertTrue(url.absoluteString.contains("%26"))
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first { $0.name == "subject" }?.value, suggestion.subject)
        XCTAssertEqual(items.first { $0.name == "body" }?.value, suggestion.body)
    }
}
