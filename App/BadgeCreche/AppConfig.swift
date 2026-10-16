import Foundation

/// Tous les textes et liens propres à l'APPC sont regroupés ici.
enum AppConfig {
    static let appName = "Badge Crèche"

    // MARK: Association

    static let associationName = "Parents à Paris Centre"
    static let associationShortName = "APPC"
    static let whatsappCommunityURL = URL(string: "https://chat.whatsapp.com/CiqGioqeO4yA93wTwvFJMW")!

    // MARK: Liens (site GitHub Pages généré depuis le dossier docs/ du dépôt)

    static let websiteURL = URL(string: "https://tikris.github.io/appc-badgeuse/")!
    static let privacyPolicyURL = URL(string: "https://tikris.github.io/appc-badgeuse/confidentialite.html")!
    static let legalNoticeURL = URL(string: "https://tikris.github.io/appc-badgeuse/mentions-legales.html")!
    static let sourceCodeURL = URL(string: "https://github.com/tikris/appc-badgeuse")!

    // MARK: Mentions légales

    #warning("Compléter les mentions légales de l'APPC (siège, RNA, directeur de la publication, e-mail) puis supprimer ce #warning.")
    static let contactEmail = "" // ex. "contact@mondomaine.fr" (laisser vide masque la ligne)
    static let legalSeat = "[Adresse du siège social – à compléter]"
    static let legalRegistration = "Association loi 1901 – RNA [W75XXXXXXX – à compléter]"
    static let publicationDirector = "[Prénom Nom – à compléter], président de l'APPC"

    // MARK: Pass Wallet

    static let passBranding = PassBranding(
        defaultTitle: "Badge crèche",
        backgroundColor: "rgb(34, 48, 90)",
        foregroundColor: "rgb(255, 255, 255)",
        labelColor: "rgb(255, 176, 150)",
        relevantText: "Vous arrivez à la crèche : votre badge est prêt.",
        usageText: "Présentez ce QR code à la badgeuse à l'arrivée et au départ. Le badge apparaît automatiquement sur l'écran verrouillé à l'approche de la crèche. Gardez votre badge d'origine en secours.",
        aboutText: "Badge créé avec l'application Badge Crèche, une initiative bénévole de l'association Parents à Paris Centre (APPC). Application indépendante, non affiliée à la Ville de Paris ni au gestionnaire de votre crèche.",
        communityURL: "https://chat.whatsapp.com/CiqGioqeO4yA93wTwvFJMW",
        communityLinkTitle: "Rejoindre la communauté WhatsApp de l'APPC",
        privacyText: "Badge créé sur votre iPhone. L'application ne stocke rien dans le cloud et ne transmet rien à l'APPC : vos données vous appartiennent."
    )
}
