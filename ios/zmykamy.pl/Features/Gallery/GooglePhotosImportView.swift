import AuthenticationServices
import SwiftUI

struct GooglePhotosImportView: View {
    let trip: Trip

    @Environment(GooglePhotosImporter.self) private var importer
    @Environment(GalleryStore.self) private var gallery
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @Environment(\.openURL) private var openURL
    @Environment(\.theme) private var theme
    @State private var isShowingError = false

    private var phase: GooglePhotosImporter.Phase {
        importer.phase(for: trip)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s24) {
                Text("Wybierz zdjęcia i filmy z Google Photos, a skopiujemy je do galerii wyjazdu obok tych dodanych w aplikacji.")
                    .typography(.subheadRegular)
                    .foregroundStyle(.neutralGray)
                    .padding(.horizontal, Spacing.s6)

                FormSection(
                    title: "GOOGLE PHOTOS",
                    footnote: "Zdjęcia są kopiowane do galerii wyjazdu. Ponowny import pominie te, które już tu są, a zmiany w Google Photos nie wpływają na galerię.",
                    separatorInset: 62
                ) {
                    accountRow
                    actionRow
                    if let date = importer.lastImport[trip.id] {
                        lastImportRow(date)
                    }
                    if importer.isConnected && !importer.isRunning {
                        disconnectRow
                    }
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.s12)
            .padding(.bottom, 48)
        }
        .background { theme.background.ignoresSafeArea() }
        .navigationTitle("Google Photos")
        .navigationSubtitle(trip.name)
        .onChange(of: phase) { _, phase in
            if case .failed = phase { isShowingError = true }
        }
        .alert("Import się nie udał", isPresented: $isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            if case .failed(let message) = phase {
                Text(message)
            }
        }
    }

    private var accountRow: some View {
        row {
            IconBadge(image: .photoLibrary, foreground: .statusSuccess, background: .statusSuccessTint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Google Photos")
                    .typography(.bodyRegular)
                    .foregroundStyle(.neutralInk)
                Text(status)
                    .typography(.footnote)
                    .foregroundStyle(.neutralGray)
            }
            Spacer(minLength: Spacing.s8)
            if importer.isConnected {
                Text("Połączono")
                    .typography(.captionEmphasis)
                    .foregroundStyle(.statusSuccess)
                    .padding(.horizontal, Spacing.s8)
                    .padding(.vertical, Spacing.s4)
                    .background(.statusSuccessTint, in: .capsule)
            }
        }
    }

    private var status: String {
        switch phase {
        case .signingIn: "Logowanie do Google…"
        case .picking: "Wybierz zdjęcia w Google Photos i wróć tutaj"
        case .downloading(let done, let total): "Pobieranie \(min(done + 1, total)) z \(total)"
        case .finished(let result): result.summary
        case .idle, .failed: importer.isConnected ? "Konto Google połączone" : "Zaloguj się kontem Google, żeby wybrać zdjęcia"
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        switch phase {
        case .signingIn, .picking, .downloading:
            row {
                IconBadge(image: .download, foreground: theme.accent, background: theme.accentTint)
                VStack(alignment: .leading, spacing: Spacing.s6) {
                    if case .downloading(let done, let total) = phase {
                        ProgressView(value: Double(done), total: Double(max(total, 1)))
                            .tint(theme.accent)
                    } else if case .picking(let url?) = phase {
                        Button("Otwórz Google Photos") { openURL(url) }
                            .typography(.bodyRegular)
                            .foregroundStyle(theme.accentStrong)
                    } else {
                        ProgressView()
                    }
                }
                Spacer(minLength: Spacing.s8)
                Button("Anuluj") { importer.cancel() }
                    .typography(.subheadEmphasis)
                    .foregroundStyle(theme.accentStrong)
            }
        case .idle, .finished, .failed:
            Button(action: start) {
                row {
                    IconBadge(image: .download, foreground: theme.accent, background: theme.accentTint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Importuj zdjęcia")
                            .typography(.bodyRegular)
                            .foregroundStyle(.neutralInk)
                        Text("Wybierz zdjęcia i filmy z biblioteki lub albumu")
                            .typography(.footnote)
                            .foregroundStyle(.neutralGray)
                    }
                    Spacer(minLength: Spacing.s8)
                    Text("Wybierz")
                        .typography(.subheadEmphasis)
                        .foregroundStyle(theme.accentStrong)
                }
            }
            .buttonStyle(.plain)
            .disabled(importer.isRunning)
        }
    }

    private func lastImportRow(_ date: Date) -> some View {
        row {
            IconBadge(image: .schedule, foreground: theme.accent, background: theme.accentTint)
            Text("Ostatni import")
                .typography(.bodyRegular)
                .foregroundStyle(.neutralInk)
            Spacer(minLength: Spacing.s8)
            Text(lastImportText(date))
                .typography(.calloutRegular)
                .foregroundStyle(.neutralGray)
        }
    }

    private var disconnectRow: some View {
        Button { importer.disconnect() } label: {
            row {
                IconBadge(image: .delete, foreground: .statusWarning, background: .statusWarningTint)
                Text("Odłącz konto Google")
                    .typography(.bodyRegular)
                    .foregroundStyle(.statusWarning)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }

    private func row(@ViewBuilder _ content: () -> some View) -> some View {
        HStack(spacing: Spacing.s12) {
            content()
        }
        .padding(.leading, Spacing.s14)
        .padding(.trailing, Spacing.s16)
        .padding(.vertical, Spacing.s12)
        .frame(minHeight: 58)
        .contentShape(.rect)
    }

    private func lastImportText(_ date: Date) -> String {
        let time = date.formatted(.dateTime.hour().minute().locale(Locale(identifier: "pl_PL")))
        if Calendar.current.isDateInToday(date) { return "dziś, \(time)" }
        return date.formatted(.dateTime.day().month().hour().minute().locale(Locale(identifier: "pl_PL")))
    }

    private func start() {
        importer.start(into: trip, gallery: gallery, authenticate: authenticate, open: { openURL($0) })
    }

    private func authenticate(_ url: URL, _ scheme: String) async throws(GooglePhotosError) -> URL {
        do {
            return try await webAuthenticationSession.authenticate(
                using: url,
                callbackURLScheme: scheme,
                preferredBrowserSession: .shared
            )
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            throw .cancelled
        } catch {
            throw .signInFailed
        }
    }
}
