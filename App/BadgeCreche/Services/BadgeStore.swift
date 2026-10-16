import Foundation
import Observation

/// Stockage local du badge : un fichier JSON chiffré par iOS (protection des données),
/// jamais envoyé sur un serveur et exclu des sauvegardes iCloud de l'appareil.
@MainActor
@Observable
final class BadgeStore {
    private(set) var badge: BadgeData?
    /// Vrai après une modification : la copie présente dans Wallet doit être remplacée.
    var needsWalletRefresh = false

    private let fileURL: URL

    init() {
        let directory = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? FileManager.default.temporaryDirectory
        fileURL = directory.appendingPathComponent("badge.json")
        if let data = try? Data(contentsOf: fileURL) {
            badge = try? JSONDecoder().decode(BadgeData.self, from: data)
        }
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

    func delete() {
        try? FileManager.default.removeItem(at: fileURL)
        badge = nil
        needsWalletRefresh = false
    }
}
