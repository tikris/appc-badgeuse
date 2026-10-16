import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Régénère l'image du QR code pour l'aperçu dans l'application.
enum QRCodeImage {
    static func make(from payload: String) -> UIImage? {
        let encoding: String.Encoding = BadgeData.messageEncoding(for: payload) == "utf-8" ? .utf8 : .isoLatin1
        guard let message = payload.data(using: encoding) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = message
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
