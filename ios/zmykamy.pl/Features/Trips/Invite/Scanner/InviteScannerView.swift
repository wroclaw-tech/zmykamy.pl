import SwiftUI

/// Full-screen camera that waits for a Zmykamy invite QR code and hands its slug back.
struct InviteScannerView: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.theme) private var theme

    private struct Rejection: Equatable {
        let id = UUID()
        let payload: String
    }

    @State private var permissions = PermissionsModel()
    @State private var hasCheckedPermission = false
    @State private var scannedSlug: String?
    @State private var rejection: Rejection?
    @State private var scannerFailed = false

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Zamknij", image: .close) { dismiss() }
                    }
                }
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
        } else if permissions.camera != .granted {
            unavailable(
                title: "Brak dostępu do aparatu",
                description: "Zezwól Zmykamy na dostęp do aparatu w Ustawieniach, żeby skanować kody QR zaproszeń."
            ) {
                Button("Otwórz Ustawienia") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .buttonStyle(.glassProminent)
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
            }
        } else if !QRScannerView.isAvailable {
            unavailable(
                title: "Skanowanie niedostępne",
                description: "To urządzenie nie obsługuje skanowania kodów QR aparatem."
            ) {
                EmptyView()
            }
        } else {
            QRScannerView(isScanning: scannedSlug == nil, onScan: handle, onUnavailable: {
                rejection = nil
                scannerFailed = true
            })
                .ignoresSafeArea()
                .overlay(alignment: .bottom) { hint }
                .accessibilityLabel("Podgląd aparatu")
        }
    }

    private var hint: some View {
        let isRejected = rejection != nil
        return HStack(spacing: Spacing.s8) {
            Image(isRejected ? .info : .qrCodeScanner)
                .resizable()
                .frame(width: 20, height: 20)
            Text(isRejected ? "To nie jest kod zaproszenia Zmykamy" : "Nakieruj aparat na kod QR zaproszenia")
                .typography(.subheadEmphasis)
        }
        .foregroundStyle(.neutralInk)
        .padding(.horizontal, Spacing.s16)
        .frame(minHeight: 44)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, Spacing.s24)
        .padding(.bottom, Spacing.s24)
        .contentTransition(.opacity)
        .animation(.smooth, value: isRejected)
        .accessibilityElement(children: .combine)
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
            scannedSlug = slug
            onScan(slug)
            dismiss()
        } else if rejection?.payload != payload {
            withAnimation(.smooth) { rejection = Rejection(payload: payload) }
            AccessibilityNotification.Announcement("To nie jest kod zaproszenia Zmykamy").post()
        }
    }
}

#Preview {
    InviteScannerView { _ in }
}
