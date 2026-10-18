import CoreImage
import Foundation
import ImageIO
import Vision

nonisolated enum QRCodeReaderError: LocalizedError {
    case noQRCode
    case unreadableFile

    var errorDescription: String? {
        switch self {
        case .noQRCode:
            "Aucun QR code détecté. Essayez avec une image plus nette, bien cadrée sur le QR code."
        case .unreadableFile:
            "Ce fichier n'a pas pu être lu. Utilisez une photo, une capture d'écran ou un PDF."
        }
    }
}

/// Retrouve le contenu du QR code dans une photo, une capture d'écran ou un PDF.
/// La détection tourne hors du fil principal (fonctions `nonisolated`).
@MainActor
enum QRCodeReader {
    static func payload(in fileData: Data) async throws -> String {
        let payloads = await Task.detached(priority: .userInitiated) {
            QRCodeReader.detectPayloads(in: fileData)
        }.value
        guard let payloads else { throw QRCodeReaderError.unreadableFile }
        guard let first = payloads.first else { throw QRCodeReaderError.noQRCode }
        return first
    }

    /// `nil` si le fichier n'est ni une image ni un PDF lisible.
    ///
    /// Une photo est d'abord décodée en version réduite (2048 px, ~12 Mo de mémoire au lieu
    /// de ~48 Mo pour 12 Mpx), ce qui suffit pour un QR code ; la pleine résolution n'est
    /// tentée qu'en cas d'échec sur une grande image.
    nonisolated static func detectPayloads(in fileData: Data) -> [String]? {
        if fileData.starts(with: Array("%PDF".utf8)) {
            return detectPayloads(inPDF: fileData)
        }
        guard let source = CGImageSourceCreateWithData(fileData as CFData, nil),
              CGImageSourceGetCount(source) > 0 else { return nil }

        let reducedSize = 2048
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: reducedSize,
        ]
        if let reduced = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            let payloads = detectPayloads(in: reduced)
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
            let width = properties?[kCGImagePropertyPixelWidth as String] as? Int ?? 0
            let height = properties?[kCGImagePropertyPixelHeight as String] as? Int ?? 0
            if !payloads.isEmpty || max(width, height) <= reducedSize { return payloads }
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return detectPayloads(in: image)
    }

    nonisolated static func detectPayloads(in image: CGImage) -> [String] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        if (try? VNImageRequestHandler(cgImage: image, options: [:]).perform([request])) != nil {
            let payloads = (request.results ?? []).compactMap(\.payloadStringValue)
            if !payloads.isEmpty { return payloads }
        }
        // Repli Core Image (utile notamment sur le simulateur).
        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
        return (detector?.features(in: CIImage(cgImage: image)) ?? [])
            .compactMap { ($0 as? CIQRCodeFeature)?.messageString }
    }

    /// Rend les premières pages du PDF en image (2048 px) puis cherche un QR code.
    nonisolated static func detectPayloads(inPDF data: Data) -> [String]? {
        guard let provider = CGDataProvider(data: data as CFData),
              let document = CGPDFDocument(provider) else { return nil }
        for index in stride(from: 1, through: min(document.numberOfPages, 5), by: 1) {
            guard let page = document.page(at: index) else { continue }
            let box = page.getBoxRect(.mediaBox)
            guard box.width > 0, box.height > 0 else { continue }
            let scale = 2048 / max(box.width, box.height)
            let width = Int(box.width * scale)
            let height = Int(box.height * scale)
            guard let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { continue }
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -box.minX, y: -box.minY)
            context.drawPDFPage(page)
            if let image = context.makeImage() {
                let payloads = detectPayloads(in: image)
                if !payloads.isEmpty { return payloads }
            }
        }
        return []
    }
}
