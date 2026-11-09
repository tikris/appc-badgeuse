import SwiftUI

/// Plusieurs badges (plusieurs enfants, nounou) : un aperçu par badge, à ouvrir pour l'ajouter à
/// Wallet, le modifier ou le supprimer. Le QR code reste visible ici, en secours.
struct BadgeListView: View {
    let badges: [BadgeData]
    let onAdd: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(badges, id: \.serialNumber) { badge in
                    NavigationLink(value: badge.serialNumber) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(badge.listTitle)
                                        .font(.headline)
                                    if let subtitle = badge.listSubtitle {
                                        Text(subtitle)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                            BadgeCardView(badge: badge)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Ouvre le badge : Wallet, modification, suppression")
                }

                Button(action: onAdd) {
                    Label("Ajouter un badge", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Text("Un badge par enfant et par crèche : chacun apparaît séparément dans Apple Wallet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
    }
}
