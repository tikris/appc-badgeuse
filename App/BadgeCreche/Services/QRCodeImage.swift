import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Régénère l'image du QR code pour l'aperçu dans l'application.
///
/// L'image est produite à 1 pixel par module (quelques Ko) et agrandie à l'affichage
/// sans lissage ; elle est mise en cache, et le contexte Core Image, coûteux à créer,
/// est partagé.
@MainActor
enum QRCodeImage {
    private static let context = CIContext()
    private static let cache = NSCache<NSString, UIImage>()

    static func make(from payload: String) -> UIImage? {
        if let cached = cache.object(forKey: payload as NSString) { return cached }
        let encoding: String.Encoding = BadgeData.messageEncoding(for: payload) == "utf-8" ? .utf8 : .isoLatin1
        guard let message = payload.data(using: encoding) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = message
        filter.correctionLevel = "M"
        guard let output = filter.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else { return nil }
        let image = UIImage(cgImage: cgImage)
        cache.setObject(image, forKey: payload as NSString)
        return image
    }
}
