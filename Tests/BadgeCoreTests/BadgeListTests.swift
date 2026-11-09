import Foundation
import XCTest
@testable import BadgeCore

/// Plusieurs badges (plusieurs enfants, nounou) : enregistrement et noms affichés dans la liste.
final class BadgeListTests: XCTestCase {
    private func badge(_ serial: String, child: String = "", creche: String = "", address: String? = nil) -> BadgeData {
        BadgeData(
            serialNumber: serial,
            qrPayload: "APPC-DEMO-BADGE-0001",
            showsChildName: !child.isEmpty,
            childFirstName: child,
            childLastName: "",
            crecheName: creche,
            address: CrecheAddress(label: "2 rue de Rivoli, 75004 Paris", latitude: 48.8556, longitude: 2.36, name: address),
            updatedAt: Date(timeIntervalSince1970: 1_790_000_000)
        )
    }

    func testListIsSavedAsAnArray() throws {
        let badges = [badge("A", child: "Léa"), badge("B", child: "Tom", creche: "Crèche des Lilas")]
        XCTAssertEqual(try BadgeData.list(from: JSONEncoder().encode(badges)), badges)
    }

    func testSingleBadgeOfVersionOneIsReadAsAList() throws {
        // Version 1 : badge.json contenait un seul badge, pas un tableau.
        let single = badge("A", child: "Léa")
        XCTAssertEqual(try BadgeData.list(from: JSONEncoder().encode(single)), [single])
    }

    func testUnreadableFileIsAnError() {
        XCTAssertThrowsError(try BadgeData.list(from: Data("pas du json".utf8)))
    }

    func testListTitleDistinguishesBadges() {
        XCTAssertEqual(badge("A", child: "Léa", creche: "Crèche des Lilas").listTitle, "Léa")
        XCTAssertEqual(badge("A", creche: "Crèche des Lilas").listTitle, "Crèche des Lilas")
        // Noms masqués sur le pass : la crèche choisie dans la liste reste visible dans l'app.
        XCTAssertEqual(badge("A", address: "Crèche Rivoli").listTitle, "Crèche Rivoli")
        XCTAssertEqual(badge("A").listTitle, "Badge")
    }

    func testListSubtitleShowsTheCrecheOnce() {
        XCTAssertEqual(badge("A", child: "Léa", address: "Crèche Rivoli").listSubtitle, "Crèche Rivoli")
        XCTAssertNil(badge("A", address: "Crèche Rivoli").listSubtitle)
        XCTAssertEqual(badge("A", child: "Léa").listSubtitle, "2 rue de Rivoli, 75004 Paris")
    }
}
