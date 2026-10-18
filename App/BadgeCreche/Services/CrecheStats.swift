import Foundation

/// Envoi des statistiques facultatives au Matomo de l'APPC (voir CrecheStat) : rien n'est envoyé
/// sans l'accord explicite du parent, ni si aucun serveur n'est configuré (AppConfig.statsEndpoint).
@MainActor
enum CrecheStats {
    /// Accord du parent (désactivé par défaut), modifiable à la création du badge et dans À propos.
    static let consentKey = "sharesCrecheStats"

    /// L'option n'est proposée que si un serveur est configuré (jamais pendant les captures d'écran).
    static var isAvailable: Bool {
        AppConfig.statsEndpoint != nil && ScreenshotMode.scene == nil
    }

    /// Sans cookie, sans cache et avec un User-Agent générique : rien qui permette de reconnaître l'iPhone.
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.httpAdditionalHeaders = ["User-Agent": "BadgeCreche"]
        return URLSession(configuration: configuration)
    }()

    /// Envoi unique, sans nouvel essai : une statistique perdue (hors connexion) n'est pas grave.
    static func send(_ stat: CrecheStat) {
        guard isAvailable,
              UserDefaults.standard.bool(forKey: consentKey),
              let endpoint = AppConfig.statsEndpoint,
              let url = stat.trackingURL(endpoint: endpoint, siteID: AppConfig.statsSiteID)
        else { return }
        session.dataTask(with: url).resume()
    }
}
