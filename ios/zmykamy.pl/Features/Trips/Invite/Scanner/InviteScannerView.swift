import PhotosUI
import SwiftUI

/// Full-screen camera that waits for a Zmykamy invite QR code and hands its slug back.
/// The code can also be read from a photo or screenshot picked from the library.
struct InviteScannerView: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.theme) private var theme

    private struct Rejection: Equatable {
        let id = UUID()
        /// The scanned text, so the camera doesn't keep rejecting the same code; nil for picked photos.
        let payload: String?
        let message: String
    }

    @State private var permissions = PermissionsModel()
    @State private var hasCheckedPermission = false
    @State private var scannedSlug: String?
    @State private var rejection: Rejection?
    @State private var scannerFailed = false
    @State private var isPickingPhoto = false
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    if isScannerLive || rejection != nil { hint }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Zamknij", image: .close) { dismiss() }
                    }
                    if isScannerLive {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Wybierz z galerii", image: .photoLibrary) { isPickingPhoto = true }
                        }
                    }
                }
        }
        .photosPicker(isPresented: $isPickingPhoto, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            Task { await scanPhoto(item) }
        }
        .task { await checkPermission() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, hasCheckedPermission else { return }
            Task { await permissions.refresh() }
        }
        .task(id: rejection?.id) {
            guard rejection != nil else { return }
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.smooth) { rejection = nil }
        }
        .sensoryFeedback(.success, trigger: scannedSlug)
        .sensoryFeedback(.warning, trigger: rejection?.id) { _, new in new != nil }
    }

    @ViewBuilder
    private var content: some View {
        if !hasCheckedPermission {
            Color.black.ignoresSafeArea()
        } else if permissions.camera == .notDetermined {
            unavailable(
                title: "Skanuj kod aparatem",
                description: "Zezwól Zmykamy na dostęp do aparatu, żeby skanować kody QR zaproszeń, albo wybierz zdjęcie kodu z galerii."
            ) {
                Button("Pozwól na dostęp do aparatu") {
                    Task { await permissions.requestCamera() }
                }
                .buttonStyle(.glassProminent)
                pickPhotoButton
            }
        } else if permissions.camera == .denied {
            // iOS shows the permission prompt only once; after a refusal only Settings can turn the camera back on.
            unavailable(
                title: "Brak dostępu do aparatu",
                description: "Wybierz zdjęcie lub zrzut ekranu z kodem QR z galerii albo włącz dostęp do aparatu w Ustawieniach."
            ) {
                Button("Wybierz z galerii") { isPickingPhoto = true }
                    .buttonStyle(.glassProminent)
                Button("Otwórz Ustawienia") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.glass)
            }
        } else if scannerFailed {
            unavailable(
                title: "Nie udało się uruchomić skanowania",
                description: "Aparat jest chwilowo niedostępny. Spróbuj ponownie."
            ) {
                Button("Spróbuj ponownie") {
                    Task {
                        await permissions.refresh()
                        scannerFailed = false
                    }
                }
                .buttonStyle(.glassProminent)
                pickPhotoButton
            }
        } else if !QRScannerView.isAvailable {
            unavailable(
                title: "Skanowanie niedostępne",
                description: "To urządzenie nie obsługuje skanowania kodów QR aparatem. Wybierz zdjęcie kodu z galerii."
            ) {
                Button("Wybierz z galerii") { isPickingPhoto = true }
                    .buttonStyle(.glassProminent)
            }
        } else {
            QRScannerView(isScanning: scannedSlug == nil, onScan: handle, onUnavailable: {
                rejection = nil
                scannerFailed = true
            })
                .ignoresSafeArea()
                .accessibilityLabel("Podgląd aparatu")
        }
    }

    private var hint: some View {
        let isRejected = rejection != nil
        return HStack(spacing: Spacing.s8) {
            Image(isRejected ? .info : .qrCodeScanner)
                .resizable()
                .frame(width: 20, height: 20)
            Text(rejection?.message ?? "Nakieruj aparat na kod QR zaproszenia")
                .typography(.subheadEmphasis)
        }
        .foregroundStyle(.neutralInk)
        .padding(.horizontal, Spacing.s16)
        .frame(minHeight: 44)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, Spacing.s24)
        .padding(.bottom, Spacing.s24)
        .contentTransition(.opacity)
        .animation(.smooth, value: rejection?.message)
        .accessibilityElement(children: .combine)
    }

    private var isScannerLive: Bool {
        hasCheckedPermission && permissions.camera == .granted && !scannerFailed && QRScannerView.isAvailable
    }

    private var pickPhotoButton: some View {
        Button("Wybierz z galerii") { isPickingPhoto = true }
            .buttonStyle(.glass)
    }

    private func unavailable(
        title: String,
        description: String,
        @ViewBuilder actions: () -> some View
    ) -> some View {
        ContentUnavailableView {
            Label(title, image: .photoCamera)
        } description: {
            Text(description)
        } actions: {
            actions()
        }
        .background { theme.background.ignoresSafeArea() }
    }

    private func checkPermission() async {
        await permissions.refresh()
        if permissions.camera == .notDetermined {
            await permissions.requestCamera()
        }
        hasCheckedPermission = true
    }

    private func handle(_ payload: String) {
        guard scannedSlug == nil else { return }
        if let slug = InviteLink.slug(from: payload) {
            accept(slug)
        } else if rejection?.payload != payload {
            reject(Rejection(payload: payload, message: "To nie jest kod zaproszenia Zmykamy"))
        }
    }

    private func scanPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            reject(Rejection(payload: nil, message: "Nie udało się wczytać zdjęcia"))
            return
        }
        let payloads = await Task.detached { QRImageReader.payloads(in: data) }.value
        guard scannedSlug == nil else { return }
        if let slug = payloads.lazy.compactMap(InviteLink.slug(from:)).first {
            accept(slug)
        } else if payloads.isEmpty {
            reject(Rejection(payload: nil, message: "Na zdjęciu nie ma kodu QR"))
        } else {
            reject(Rejection(payload: nil, message: "To nie jest kod zaproszenia Zmykamy"))
        }
    }

    private func accept(_ slug: String) {
        scannedSlug = slug
        onScan(slug)
        dismiss()
    }

    private func reject(_ rejection: Rejection) {
        withAnimation(.smooth) { self.rejection = rejection }
        AccessibilityNotification.Announcement(rejection.message).post()
    }
}

#Preview {
    InviteScannerView { _ in }
}
