import SwiftUI

/// Ligne d'attente d'un formulaire ou d'une liste : indicateur d'activité et texte discret.
struct ProgressRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}
