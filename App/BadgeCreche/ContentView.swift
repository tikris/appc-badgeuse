import SwiftUI

/// Écran racine. À utiliser tel quel depuis le fichier `…App.swift` créé par Xcode :
/// `WindowGroup { ContentView() }`.
struct ContentView: View {
    @State private var store: BadgeStore
    @State private var isEditing: Bool
    @State private var isShowingAbout: Bool

    init() {
        let scene = ScreenshotMode.scene
        if let scene {
            let showsBadge = scene == .badge || scene == .about
            _store = State(initialValue: BadgeStore(inMemory: showsBadge ? ScreenshotMode.demoBadge : nil))
        } else {
            _store = State(initialValue: BadgeStore())
        }
        _isEditing = State(initialValue: scene == .editor)
        _isShowingAbout = State(initialValue: scene == .about)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let badge = store.badge {
                    BadgeHomeView(badge: badge, store: store) { isEditing = true }
                } else {
                    WelcomeView { isEditing = true }
                }
            }
            .navigationTitle(AppConfig.appName)
            .navigationBarTitleDisplayMode(.inline)
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
        .sheet(isPresented: $isEditing) {
            BadgeEditorView(existing: store.badge, prefill: ScreenshotMode.scene.map { _ in ScreenshotMode.demoBadge }) { badge in
                try store.save(badge)
            }
            .tint(.appcTint)
        }
        .sheet(isPresented: $isShowingAbout) {
            AboutView()
                .tint(.appcTint)
        }
    }
}
