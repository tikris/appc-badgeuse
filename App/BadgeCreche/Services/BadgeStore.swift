import Foundation
import Observation

/// Stockage local du badge : un fichier JSON chiffré par iOS (protection des données),
/// jamais envoyé sur un serveur et exclu des sauvegardes iCloud de l'appareil.
@MainActor
@Observable
final class BadgeStore {
    private(set) var badge: BadgeData?
    /// Vrai après une modification : la copie présente dans Wallet doit être remplacée.
    private(set) var needsWalletRefresh = false

    /// À incrémenter quand le contenu du pass change (rayon d'affichage…) : la copie présente
    /// dans Wallet est alors remplacée au lancement suivant, sans action du parent.
    private static let passRevision = 4
    private static let passRevisionKey = "passRevision"

    /// Avec l'option « heures de crèche », le pass porte six mois de créneaux datés : la copie de
    /// Wallet est renouvelée à l'ouverture de l'app quand elle a plus d'un mois.
    private static let walletWrittenKey = "walletWrittenAt"
    private static let crecheHoursRenewal: TimeInterval = 30 * 24 * 3600

    private let fileURL: URL

    init() {
        let directory = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? FileManager.default.temporaryDirectory
        fileURL = directory.appendingPathComponent("badge.json")
        if let data = try? Data(contentsOf: fileURL) {
            badge = try? JSONDecoder().decode(BadgeData.self, from: data)
        }
        let revisionIsOutdated = UserDefaults.standard.integer(forKey: Self.passRevisionKey) < Self.passRevision
        let lastWrite = UserDefaults.standard.object(forKey: Self.walletWrittenKey) as? Date ?? .distantPast
        let hoursAreRunningOut = badge?.limitsLockScreenToCrecheHours == true
            && Date().timeIntervalSince(lastWrite) > Self.crecheHoursRenewal
        needsWalletRefresh = badge != nil && (revisionIsOutdated || hoursAreRunningOut)
    }

    /// Badge de démonstration gardé en mémoire (captures d'écran).
    init(inMemory badge: BadgeData?) {
        fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("demo-badge.json")
        self.badge = badge
    }

    func save(_ newBadge: BadgeData) throws {
        let data = try JSONEncoder().encode(newBadge)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var url = fileURL
        try url.setResourceValues(values)
        needsWalletRefresh = badge != nil
        badge = newBadge
    }

    /// Le pass généré est à jour : inutile de remplacer de nouveau la copie de Wallet.
    func walletRefreshed() {
        if needsWalletRefresh {
            needsWalletRefresh = false
            UserDefaults.standard.set(Date(), forKey: Self.walletWrittenKey)
        }
        UserDefaults.standard.set(Self.passRevision, forKey: Self.passRevisionKey)
    }

    func delete() {
        try? FileManager.default.removeItem(at: fileURL)
        badge = nil
        needsWalletRefresh = false
    }
}
