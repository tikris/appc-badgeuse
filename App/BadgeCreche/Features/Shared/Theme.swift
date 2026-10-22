import SwiftUI

/// Couleurs de l'APPC, communes à l'application et au pass.
extension Color {
    static let appcCoral = Color(red: 255 / 255, green: 122 / 255, blue: 89 / 255)
    static let appcNavy = Color(red: 34 / 255, green: 48 / 255, blue: 90 / 255)
    static let appcLabel = Color(red: 255 / 255, green: 176 / 255, blue: 150 / 255)
    /// Bleu marine en mode clair, corail en mode sombre (contraste suffisant dans les deux cas).
    static let appcTint = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 255 / 255, green: 138 / 255, blue: 107 / 255, alpha: 1)
            : UIColor(red: 34 / 255, green: 48 / 255, blue: 90 / 255, alpha: 1)
    })
}
