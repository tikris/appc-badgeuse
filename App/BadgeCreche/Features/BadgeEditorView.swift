import AVFoundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Création / modification du badge : crèche (proposée d'après la position), QR code,
/// et ce qui s'affiche sur le badge (noms de la crèche et de l'enfant, facultatifs).
struct BadgeEditorView: View {
    let existing: BadgeData?
    let onSave: (BadgeData) throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var qrPayload: String?
    @State private var showsChildName: Bool
    @State private var childFirstName: String
    @State private var childLastName: String
    @State private var showsCrecheName: Bool
    @State private var crecheName: String
    @State private var address: CrecheAddress?

    @State private var isScanning = false
    @State private var isImportingFile = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isReadingQRCode = false
    @State private var errorMessage: String?

    /// `prefill` : valeurs initiales d'un nouveau badge (captures d'écran).
    init(existing: BadgeData?, prefill: BadgeData? = nil, onSave: @escaping (BadgeData) throws -> Void) {
        self.existing = existing
        self.onSave = onSave
        let initial = existing ?? prefill
        _qrPayload = State(initialValue: initial?.qrPayload)
        _showsChildName = State(initialValue: initial?.showsChildName ?? false)
        _childFirstName = State(initialValue: initial?.childFirstName ?? "")
        _childLastName = State(initialValue: initial?.childLastName ?? "")
        let storedName = existing?.crecheName ?? ""
        _showsCrecheName = State(initialValue: existing == nil || !storedName.isEmpty)
        _crecheName = State(initialValue: storedName.isEmpty ? (existing?.address.name ?? "") : storedName)
        // Pour un nouveau badge, la crèche est choisie d'après la position (pas de préremplissage).
        _address = State(initialValue: existing?.address)
    }

    private var canSave: Bool {
        qrPayload != nil && address != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                CrecheSection(address: $address, onSelect: { crecheName = $0 }, locatesOnAppear: existing == nil)
                qrSection
                displaySection
            }
            .navigationTitle(existing == nil ? "Nouveau badge" : "Modifier le badge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer", action: save)
                        .disabled(!canSave)
                }
            }
            .fullScreenCover(isPresented: $isScanning) {
                scannerScreen
            }
            .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.image, .pdf]) { result in
                importFile(result)
            }
            .onChange(of: photoItem) { _, item in
                importPhoto(item)
            }
            .alert("Oups", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: Sections

    private var qrSection: some View {
        Section {
            if let qrPayload {
                HStack(spacing: 16) {
                    QRCodePreview(payload: qrPayload)
                        .frame(width: 88, height: 88)
                    VStack(alignment: .leading, spacing: 4) {
                        Label("QR code prêt", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                        Text(qrPayload)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }
                .padding(.vertical, 4)
            }
            if isReadingQRCode {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Lecture du QR code…")
                }
            }
            Button(action: startScanning) {
                Label(qrPayload == nil ? "Scanner le QR code" : "Scanner à nouveau", systemImage: "qrcode.viewfinder")
            }
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Choisir une photo ou une capture d'écran", systemImage: "photo.on.rectangle")
            }
            Button {
                isImportingFile = true
            } label: {
                Label("Importer un fichier (PDF, image)", systemImage: "doc.viewfinder")
            }
        } header: {
            Text("QR code de la crèche")
        } footer: {
            Text("Le QR code remis par la crèche en début d'année. Il est reproduit à l'identique dans votre badge.")
        }
    }

    private var displaySection: some View {
        Section {
            Toggle("Afficher le nom de la crèche", isOn: $showsCrecheName.animation())
            if showsCrecheName {
                TextField("Nom de la crèche", text: $crecheName)
                    .textInputAutocapitalization(.words)
            }
            Toggle("Afficher le nom de l'enfant", isOn: $showsChildName.animation())
            if showsChildName {
                TextField("Prénom", text: $childFirstName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                TextField("Nom (facultatif)", text: $childLastName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }
        } header: {
            Text("Sur le badge (facultatif)")
        } footer: {
            Text("Uniquement si vous le souhaitez. Ces informations restent sur votre iPhone et dans Apple Wallet : elles ne sont jamais transmises à l'APPC.")
        }
    }

    private var scannerScreen: some View {
        NavigationStack {
            QRScannerView { payload in
                qrPayload = payload
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

    // MARK: Actions

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
        isReadingQRCode = true
        Task {
            defer { isReadingQRCode = false }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw QRCodeReaderError.unreadableFile
                }
                qrPayload = try await QRCodeReader.payload(in: data)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func importFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let isAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if isAccessing { url.stopAccessingSecurityScopedResource() }
            }
            let data = try Data(contentsOf: url)
            isReadingQRCode = true
            Task {
                defer { isReadingQRCode = false }
                do {
                    qrPayload = try await QRCodeReader.payload(in: data)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        guard let qrPayload, let address else { return }
        let firstName = childFirstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastName = childLastName.trimmingCharacters(in: .whitespacesAndNewlines)
        // Minimisation : le nom n'est conservé que si le parent a choisi de l'afficher.
        let keepsName = showsChildName && !(firstName.isEmpty && lastName.isEmpty)
        let badge = BadgeData(
            serialNumber: existing?.serialNumber ?? UUID().uuidString,
            qrPayload: qrPayload,
            showsChildName: keepsName,
            childFirstName: keepsName ? firstName : "",
            childLastName: keepsName ? lastName : "",
            crecheName: showsCrecheName ? crecheName.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            address: address,
            updatedAt: Date()
        )
        do {
            try onSave(badge)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
