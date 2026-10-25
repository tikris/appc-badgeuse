import Foundation
import Observation

/// Liste des crèches embarquée (Resources/creches-paris.json) : environ 1 200 fiches lues et indexées
/// une seule fois, hors du fil principal, pour ne jamais figer l'interface.
@MainActor
@Observable
final class CrecheCatalog {
    static let shared = CrecheCatalog()

    /// nil tant que la liste n'est pas chargée (ou si le fichier manque).
    private(set) var paris: CrecheDirectory?
    private(set) var isLoaded = false
    @ObservationIgnored private var loading: Task<CrecheDirectory?, Never>?

    private init() {}

    /// Lance le chargement si besoin et attend la liste ; les appels simultanés partagent le même chargement.
    @discardableResult
    func load() async -> CrecheDirectory? {
        if isLoaded { return paris }
        let task = loading ?? Task.detached(priority: .userInitiated) { Self.readBundledList() }
        loading = task
        let directory = await task.value
        paris = directory
        isLoaded = true
        return directory
    }

    private nonisolated static func readBundledList() -> CrecheDirectory? {
        Bundle.main.url(forResource: "creches-paris", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? CrecheDirectory(data: $0) }
    }
}
