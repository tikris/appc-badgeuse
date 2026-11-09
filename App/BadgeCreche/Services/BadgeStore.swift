import Foundation
import Observation

/// Stockage local des badges : un fichier JSON chiffré par iOS (protection des données),
/// jamais envoyé sur un serveur et exclu des sauvegardes iCloud de l'appareil.
/// Plusieurs badges possibles (plusieurs enfants, nounou) : chacun est un pass distinct dans Wallet.
@MainActor
@Observable
final class BadgeStore {
    private(set) var badges: [BadgeData] = []
    /// Badges (numéros de série) dont la copie présente dans Wallet doit être remplacée.
    private var pendingWalletRefresh: Set<String> = []

    /// À incrémenter quand le contenu du pass change (rayon d'affichage…) : les copies présentes
    /// dans Wallet sont alors remplacées au lancement suivant, sans action du parent.
    private static let passRevision = 4
    private static let passRevisionKey = "passRevision"

    /// Avec l'option « heures de crèche », le pass porte six mois de créneaux datés : sa copie dans
    /// Wallet est renouvelée au lancement quand elle a plus d'un mois (date par badge).
    private static let walletWrittenKey = "walletWrittenAtBySerial"
    private static let crecheHoursRenewal: TimeInterval = 30 * 24 * 3600

    private let fileURL: URL
    private let persists: Bool

    init() {
        let directory = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? FileManager.default.temporaryDirectory
        fileURL = directory.appendingPathComponent("badges.json")
        persists = true
        let legacyURL = directory.appendingPathComponent("badge.json")
        if let data = try? Data(contentsOf: fileURL), let list = try? BadgeData.list(from: data) {
            badges = list
        } else if let data = try? Data(contentsOf: legacyURL), let list = try? BadgeData.list(from: data) {
            // Version 1 : un seul badge dans badge.json, repris dans la liste puis effacé.
            badges = list
            if (try? write(list)) != nil {
                try? FileManager.default.removeItem(at: legacyURL)
            }
        }

        let revisionIsOutdated = UserDefaults.standard.integer(forKey: Self.passRevisionKey) < Self.passRevision
        let written = Self.walletWrittenDates()
        let now = Date()
        pendingWalletRefresh = Set(badges.filter { badge in
            revisionIsOutdated || (badge.limitsLockScreenToCrecheHours
                && now.timeIntervalSince(written[badge.serialNumber] ?? .distantPast) > Self.crecheHoursRenewal)
        }.map(\.serialNumber))
    }

    /// Badges de démonstration gardés en mémoire (captures d'écran).
    init(inMemory badges: [BadgeData]) {
        fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("demo-badges.json")
        persists = false
        self.badges = badges
    }

    func badge(withSerial serial: String) -> BadgeData? {
        badges.first { $0.serialNumber == serial }
    }

    /// Ajoute un nouveau badge, ou remplace celui qui a le même numéro de série.
    func save(_ badge: BadgeData) throws {
        var updated = badges
        if let index = updated.firstIndex(where: { $0.serialNumber == badge.serialNumber }) {
            updated[index] = badge
            pendingWalletRefresh.insert(badge.serialNumber)
        } else {
            updated.append(badge)
        }
        try write(updated)
        badges = updated
    }

    /// Vrai après une modification (ou une nouvelle version du pass) : la copie de Wallet doit être remplacée.
    func needsWalletRefresh(_ serial: String) -> Bool {
        pendingWalletRefresh.contains(serial)
    }

    /// Le pass de ce badge est à jour : inutile de remplacer de nouveau la copie de Wallet.
    func walletRefreshed(_ serial: String) {
        if pendingWalletRefresh.remove(serial) != nil {
            var written = Self.walletWrittenDates()
            written[serial] = Date()
            UserDefaults.standard.set(written, forKey: Self.walletWrittenKey)
        }
        if pendingWalletRefresh.isEmpty {
            UserDefaults.standard.set(Self.passRevision, forKey: Self.passRevisionKey)
        }
    }

    func delete(_ serial: String) {
        let updated = badges.filter { $0.serialNumber != serial }
        try? write(updated)
        badges = updated
        pendingWalletRefresh.remove(serial)
        var written = Self.walletWrittenDates()
        written[serial] = nil
        UserDefaults.standard.set(written, forKey: Self.walletWrittenKey)
    }

    private func write(_ list: [BadgeData]) throws {
        guard persists else { return }
        guard !list.isEmpty else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        let data = try JSONEncoder().encode(list)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var url = fileURL
        try url.setResourceValues(values)
    }

    private static func walletWrittenDates() -> [String: Date] {
        UserDefaults.standard.dictionary(forKey: walletWrittenKey) as? [String: Date] ?? [:]
    }
}
