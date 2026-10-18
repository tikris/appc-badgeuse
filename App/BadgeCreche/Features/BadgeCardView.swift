import SwiftUI

/// Aperçu du badge, fidèle au rendu du pass dans Wallet.
struct BadgeCardView: View {
    let badge: BadgeData

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(uiImage: PassArtwork.appIcon(side: 30))
                    .resizable()
                    .frame(width: 30, height: 30)
                    .accessibilityHidden(true)
                Text(AppConfig.passBranding.defaultTitle)
                    .font(.headline)
                Spacer()
            }

            if let childName = badge.displayedChildName {
                field(label: "ENFANT", value: childName, prominent: true)
                if let crecheName = badge.displayedCrecheName {
                    field(label: "CRÈCHE", value: crecheName, prominent: false)
                }
            } else {
                field(label: "BADGE", value: badge.displayedCrecheName ?? AppConfig.passBranding.defaultTitle, prominent: true)
            }

            QRCodePreview(payload: badge.qrPayload)
                .frame(width: 160, height: 160)
                .padding(10)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: .infinity)
                .accessibilityLabel("QR code de la crèche")
        }
        .padding(20)
        .foregroundStyle(.white)
        .background(Color.appcNavy, in: RoundedRectangle(cornerRadius: 18))
    }

    private func field(label: String, value: String, prominent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.appcLabel)
            Text(value)
                .font(prominent ? .title2.weight(.semibold) : .body)
        }
        .accessibilityElement(children: .combine)
    }
}

struct QRCodePreview: View {
    let payload: String

    var body: some View {
        if let image = QRCodeImage.make(from: payload) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "qrcode")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
        }
    }
}
