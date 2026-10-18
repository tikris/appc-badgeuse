import CoreGraphics
import Foundation
import ImageIO
import XCTest
@testable import BadgeCore

final class QRCodeReaderTests: XCTestCase {
    private let expected = "APPC-DEMO-BADGE-0001"

    func testReadsScreenshot() throws {
        XCTAssertEqual(QRCodeReader.detectPayloads(in: try fixture("qr-small.png"))?.first, expected)
    }

    func testReadsTwelveMegapixelPhoto() throws {
        let data = try fixture("qr-photo-12mp.jpg")
        let clock = ContinuousClock()

        var payloads: [String]?
        let reduced = clock.measure { payloads = QRCodeReader.detectPayloads(in: data) }
        XCTAssertEqual(payloads?.first, expected)

        // Référence : décodage et détection en pleine résolution (ancien comportement).
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        var fullPayloads: [String] = []
        let full = clock.measure {
            if let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                fullPayloads = QRCodeReader.detectPayloads(in: image)
            }
        }
        XCTAssertEqual(fullPayloads.first, expected)
        print("Photo 12 Mpx : image réduite \(reduced), pleine résolution \(full)")
    }

    func testFallsBackToFullResolutionForSmallCodeInLargePhoto() throws {
        XCTAssertEqual(QRCodeReader.detectPayloads(in: try fixture("qr-photo-far.jpg"))?.first, expected)
    }

    func testReadsPDF() throws {
        XCTAssertEqual(QRCodeReader.detectPayloads(in: try fixture("qr-document.pdf"))?.first, expected)
    }

    func testBlankImageHasNoCode() throws {
        XCTAssertEqual(QRCodeReader.detectPayloads(in: try fixture("blank.png")), [])
    }

    func testRejectsNonImageFile() throws {
        XCTAssertNil(QRCodeReader.detectPayloads(in: try fixture("not-an-image.txt")))
    }

    @MainActor
    func testPayloadReportsMissingCode() async throws {
        let blank = try fixture("blank.png")
        do {
            _ = try await QRCodeReader.payload(in: blank)
            XCTFail("une erreur était attendue")
        } catch QRCodeReaderError.noQRCode {
            // attendu
        }
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }
}
