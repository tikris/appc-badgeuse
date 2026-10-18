import PassKit
import SwiftUI

/// Mode capture d'écran pour l'App Store, actif uniquement dans les builds Debug lancés avec
/// `-screenshot <scène>` (voir .github/workflows/screenshots.yml). Données fictives, rien n'est
/// enregistré sur l'appareil.
enum ScreenshotMode {
    enum Scene: String {
        case welcome, editor, badge, about
    }

    static let scene: Scene? = {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot"), index + 1 < arguments.count else { return nil }
        return Scene(rawValue: arguments[index + 1])
        #else
        return nil
        #endif
    }()

    /// Position fictive (Paris Centre) utilisée à la place du GPS pendant les captures.
    static let demoLocation: (latitude: Double, longitude: Double)? = scene == nil ? nil : (48.8566, 2.3545)

    static let demoBadge = BadgeData(
        serialNumber: "DEMO",
        qrPayload: "APPC-DEMO-BADGE-0001",
        showsChildName: true,
        childFirstName: "Léa",
        childLastName: "",
        crecheName: "Crèche des Lilas",
        address: CrecheAddress(label: "Crèche des Lilas, 75004 Paris", latitude: 48.8566, longitude: 2.3522),
        updatedAt: Date()
    )
}

/// Bouton officiel « Ajouter à Apple Wallet », affiché sans pass signé pour les captures.
struct StaticAddPassButton: UIViewRepresentable {
    func makeUIView(context: Context) -> PKAddPassButton {
        PKAddPassButton(addPassButtonStyle: .black)
    }

    func updateUIView(_ uiView: PKAddPassButton, context: Context) {}
}
