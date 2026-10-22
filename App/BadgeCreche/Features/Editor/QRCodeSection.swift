import AVFoundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// QR code remis par la crèche : scan en direct, photo ou capture d'écran, fichier (PDF, image).
/// Les présentations (scanner, sélecteur de fichier, alerte) sont attachées à une ligne précise :
/// sur une `Section`, SwiftUI les répéterait sur chaque ligne.
struct QRCodeSection: View {
    @Binding var payload: String?

    @State private var isScanning = false
    @State private var isImportingFile = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isReading = false
    @State private var errorMessage: String?

    var body: some View {
        Section {
            if let payload {
                preview(payload)
            }
            if isReading {
                ProgressRow(text: "Lecture du QR code…")
            }
            Button(action: startScanning) {
                Label(payload == nil ? "Scanner le QR code" : "Scanner à nouveau", systemImage: "qrcode.viewfinder")
            }
            .fullScreenCover(isPresented: $isScanning) {
                scannerScreen
            }
            .alert("Oups", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Choisir une photo ou une capture d'écran", systemImage: "photo.on.rectangle")
            }
            .onChange(of: photoItem) { _, item in
                importPhoto(item)
            }
            Button {
                isImportingFile = true
            } label: {
                Label("Importer un fichier (PDF, image)", systemImage: "doc.viewfinder")
            }
            .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.image, .pdf]) { result in
                importFile(result)
            }
        } header: {
            Text("QR code de la crèche")
        } footer: {
            Text("Le QR code remis par la crèche en début d'année. Il est reproduit à l'identique dans votre badge.")
        }
    }

    // MARK: Vues

    private func preview(_ payload: String) -> some View {
        HStack(spacing: 16) {
            QRCodePreview(payload: payload)
                .frame(width: 88, height: 88)
            VStack(alignment: .leading, spacing: 4) {
                Label("QR code prêt", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text(payload)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
        .padding(.vertical, 4)
    }

    private var scannerScreen: some View {
        NavigationStack {
            QRScannerView { scanned in
                payload = scanned
                isScanning = false
            }
            .ignoresSafeArea()
            .navigationTitle("Scannez le QR code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { isScanning = false }
                }
            }
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    // MARK: Lecture du QR code

    private func startScanning() {
        let deniedMessage = "Autorisez l'appareil photo dans Réglages > \(AppConfig.appName), ou importez une photo du QR code."
        guard QRScannerView.isSupported else {
            errorMessage = "Le scan en direct n'est pas disponible sur cet appareil. Importez plutôt une photo ou une capture d'écran du QR code."
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isScanning = true
        case .notDetermined:
            Task {
                if await AVCaptureDevice.requestAccess(for: .video) {
                    isScanning = true
                } else {
                    errorMessage = deniedMessage
                }
            }
        default:
            errorMessage = deniedMessage
        }
    }

    private func importPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        photoItem = nil
        read {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw QRCodeReaderError.unreadableFile
            }
            return data
        }
    }

    private func importFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let isAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if isAccessing { url.stopAccessingSecurityScopedResource() }
            }
            // Lu tout de suite : l'accès au fichier choisi n'est garanti que pendant cet appel.
            let data = try Data(contentsOf: url)
            read { data }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Décode le QR code d'une image ou d'un PDF, en affichant l'attente puis le résultat ou l'erreur.
    private func read(_ loadData: @escaping @MainActor () async throws -> Data) {
        isReading = true
        Task {
            defer { isReading = false }
            do {
                payload = try await QRCodeReader.payload(in: loadData())
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
