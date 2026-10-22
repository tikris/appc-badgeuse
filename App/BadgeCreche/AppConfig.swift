import Foundation

/// Tous les textes et liens propres à l'APPC sont regroupés ici.
enum AppConfig {
    static let appName = "Badge Crèche"

    // MARK: Association

    static let associationName = "Parents à Paris Centre"
    static let associationShortName = "APPC"
    static let whatsappCommunityURL = URL(string: "https://chat.whatsapp.com/CiqGioqeO4yA93wTwvFJMW")!

    // MARK: Liens (site GitHub Pages généré depuis le dossier docs/ du dépôt)

    static let privacyPolicyURL = URL(string: "https://tikris.github.io/appc-badgeuse/confidentialite.html")!
    static let legalNoticeURL = URL(string: "https://tikris.github.io/appc-badgeuse/mentions-legales.html")!
    static let sourceCodeURL = URL(string: "https://github.com/tikris/appc-badgeuse")!

    // MARK: Mentions légales

    static let contactEmail = "christophe.amalric@appc.paris"
    /// Reçoit les noms d'usage proposés par les parents (à reporter dans tools/creches-noms.csv).
    /// Une adresse dédiée, par exemple « badge@appc.paris », faciliterait le tri.
    static let suggestionsEmail = contactEmail
    static let legalSeat = "6, rue Montmartre, 75001 Paris"
    // À mettre à jour (ici et dans docs/mentions-legales.html) dès réception du numéro RNA.
    static let legalRegistration = "Association loi 1901 – n° RNA en cours d'attribution"
    static let publicationDirector = "Christophe Amalric, président de l'APPC"

    // MARK: Statistiques facultatives (Matomo auto-hébergé, voir MATOMO.md)

    /// Point de collecte Matomo, par ex. « https://stats.appc.paris/matomo.php ».
    /// nil : aucune statistique n'est envoyée et l'option n'apparaît pas dans l'application.
    static let statsEndpoint: URL? = nil
    static let statsSiteID = 1

    // MARK: Pass Wallet

    static let passBranding = PassBranding(
        defaultTitle: "Badge crèche",
        backgroundColor: "rgb(34, 48, 90)",
        foregroundColor: "rgb(255, 255, 255)",
        labelColor: "rgb(255, 176, 150)",
        relevantText: "Vous arrivez à la crèche : votre badge est prêt.",
        usageText: "Présentez ce QR code à la badgeuse à l'arrivée et au départ. Le badge apparaît automatiquement sur l'écran verrouillé devant la crèche. Gardez votre badge d'origine en secours.",
        aboutText: "Badge créé avec l'application Badge Crèche, une initiative bénévole de l'association Parents à Paris Centre (APPC). Application indépendante, non affiliée à la Ville de Paris ni au gestionnaire de votre crèche.",
        communityURL: "https://chat.whatsapp.com/CiqGioqeO4yA93wTwvFJMW",
        communityLinkTitle: "Rejoindre la communauté WhatsApp de l'APPC",
        privacyText: "Badge créé sur votre iPhone. Le QR code et le nom de l'enfant ne quittent jamais votre iPhone et l'APPC n'y a jamais accès : vos données vous appartiennent."
    )
}
