import SwiftUI

/// Écran racine. À utiliser tel quel depuis le fichier `…App.swift` créé par Xcode :
/// `WindowGroup { ContentView() }`.
///
/// Aucun badge : accueil. Un badge : son écran, avec « Ajouter un badge ». Plusieurs badges
/// (plusieurs enfants, nounou) : la liste, d'où l'on ouvre chacun.
struct ContentView: View {
    @State private var store: BadgeStore
    @State private var editor: EditorTarget?
    @State private var isShowingAbout: Bool
    /// Badge ouvert depuis la liste (numéro de série).
    @State private var path: [String] = []

    init() {
        let scene = ScreenshotMode.scene
        if let scene {
            let showsBadge = scene == .badge || scene == .about
            _store = State(initialValue: BadgeStore(inMemory: showsBadge ? [ScreenshotMode.demoBadge] : []))
        } else {
            _store = State(initialValue: BadgeStore())
        }
        _editor = State(initialValue: scene == .editor ? .new : nil)
        _isShowingAbout = State(initialValue: scene == .about)
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch store.badges.count {
                case 0:
                    WelcomeView { editor = .new }
                case 1:
                    home(store.badges[0], canAdd: true)
                default:
                    BadgeListView(badges: store.badges) { editor = .new }
                }
            }
            .navigationTitle(AppConfig.appName)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { serial in
                if let badge = store.badge(withSerial: serial) {
                    home(badge, canAdd: false)
                        .navigationTitle(badge.listTitle)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAbout = true
                    } label: {
                        Label("À propos", systemImage: "info.circle")
                    }
                }
            }
        }
        .tint(.appcTint)
        .task {
            await refreshWalletPasses()
        }
        .onChange(of: store.badges.map(\.serialNumber)) { _, serials in
            // Badge supprimé depuis son écran : retour à la liste.
            path.removeAll { !serials.contains($0) }
        }
        .sheet(item: $editor) { target in
            BadgeEditorView(existing: target.badge, prefill: ScreenshotMode.scene.map { _ in ScreenshotMode.demoBadge }) { badge in
                try store.save(badge)
            }
            .tint(.appcTint)
        }
        .sheet(isPresented: $isShowingAbout) {
            AboutView()
                .tint(.appcTint)
        }
    }

    private func home(_ badge: BadgeData, canAdd: Bool) -> some View {
        BadgeHomeView(
            badge: badge,
            store: store,
            onEdit: { editor = .existing(badge) },
            onAdd: canAdd ? { editor = .new } : nil
        )
    }

    /// Au lancement : remplace dans Wallet les pass dont le contenu a changé (nouvelle version du pass,
    /// horaires à prolonger), pour tous les badges et pas seulement celui affiché.
    private func refreshWalletPasses() async {
        guard ScreenshotMode.scene == nil else { return }
        for badge in store.badges where store.needsWalletRefresh(badge.serialNumber) {
            guard let pass = try? await WalletService.makePass(for: badge) else { continue }
            _ = WalletService.replaceInWallet(with: pass)
            store.walletRefreshed(badge.serialNumber)
        }
    }
}

/// Création d'un badge, ou modification d'un badge existant.
enum EditorTarget: Identifiable {
    case new
    case existing(BadgeData)

    var id: String {
        switch self {
        case .new: "nouveau"
        case .existing(let badge): badge.serialNumber
        }
    }

    var badge: BadgeData? {
        switch self {
        case .new: nil
        case .existing(let badge): badge
        }
    }
}
