import SwiftUI

/// Écran racine. À utiliser tel quel depuis le fichier `…App.swift` créé par Xcode :
/// `WindowGroup { ContentView() }`.
struct ContentView: View {
    @State private var store = BadgeStore()
    @State private var isEditing = false
    @State private var isShowingAbout = false

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
            BadgeEditorView(existing: store.badge) { badge in
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
