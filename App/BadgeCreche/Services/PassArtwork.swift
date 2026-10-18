import UIKit

/// Images du pass (icône, logo) dessinées à la volée : PNG standards, sans dépendre
/// du traitement des PNG par Xcode. Même géométrie que tools/make_icon.py.
/// Tout est calculé une seule fois puis gardé en mémoire (quelques Ko).
@MainActor
enum PassArtwork {
    static let coral = UIColor(red: 255 / 255, green: 122 / 255, blue: 89 / 255, alpha: 1)
    static let navy = UIColor(red: 34 / 255, green: 48 / 255, blue: 90 / 255, alpha: 1)

    /// icon.png / logo.png en 1x, 2x et 3x.
    static let passImages: [String: Data] = {
        var images: [String: Data] = [:]
        for scale in 1...3 {
            let suffix = scale == 1 ? "" : "@\(scale)x"
            images["icon\(suffix).png"] = renderer(side: 29, scale: scale, opaque: true).pngData { context in
                coral.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 29, height: 29))
                drawMotif(in: CGRect(x: 0, y: 0, width: 29, height: 29))
            }
            images["logo\(suffix).png"] = renderer(side: 50, scale: scale, opaque: false).pngData { _ in
                drawMotif(in: CGRect(x: 0, y: 0, width: 50, height: 50))
            }
        }
        return images
    }()

    /// Icône de l'interface (accueil, badge, À propos), dessinée une fois par taille.
    static func appIcon(side: CGFloat) -> UIImage {
        if let cached = iconCache[side] { return cached }
        let image = renderer(side: side, scale: 3, opaque: false).image { _ in
            let rect = CGRect(x: 0, y: 0, width: side, height: side)
            coral.setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: side * 0.225).fill()
            drawMotif(in: rect)
        }
        iconCache[side] = image
        return image
    }

    private static var iconCache: [CGFloat: UIImage] = [:]

    private static func renderer(side: CGFloat, scale: Int, opaque: Bool) -> UIGraphicsImageRenderer {
        let format = UIGraphicsImageRendererFormat()
        format.scale = CGFloat(scale)
        format.opaque = opaque
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
    }

    /// Maison blanche contenant un motif de QR code bleu marine.
    private static func drawMotif(in rect: CGRect) {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        func square(_ x: CGFloat, _ y: CGFloat, _ side: CGFloat) -> UIBezierPath {
            UIBezierPath(rect: CGRect(origin: point(x, y), size: CGSize(width: side * rect.width, height: side * rect.height)))
        }

        let outline: [(CGFloat, CGFloat)] = [
            (0.50, 0.15), (0.88, 0.47), (0.79, 0.47), (0.79, 0.85), (0.21, 0.85), (0.21, 0.47), (0.12, 0.47),
        ]
        let house = UIBezierPath()
        house.move(to: point(outline[0].0, outline[0].1))
        for vertex in outline.dropFirst() {
            house.addLine(to: point(vertex.0, vertex.1))
        }
        house.close()
        house.lineJoinStyle = .round
        house.lineWidth = 0.05 * rect.width
        UIColor.white.setFill()
        UIColor.white.setStroke()
        house.fill()
        house.stroke()

        let finder: CGFloat = 0.13
        let finders: [(CGFloat, CGFloat)] = [(0.34, 0.505), (0.53, 0.505), (0.34, 0.695)]
        for (x, y) in finders {
            navy.setFill()
            square(x, y, finder).fill()
            UIColor.white.setFill()
            square(x + 0.025, y + 0.025, finder - 0.05).fill()
            navy.setFill()
            square(x + 0.045, y + 0.045, finder - 0.09).fill()
        }
        let cell = finder / 3
        navy.setFill()
        for (column, row) in [(0, 0), (2, 0), (1, 1), (0, 2), (2, 2)] {
            square(0.53 + CGFloat(column) * cell, 0.695 + CGFloat(row) * cell, cell).fill()
        }
    }
}
