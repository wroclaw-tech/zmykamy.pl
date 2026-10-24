import SwiftUI

private struct DeviceRow: View {
    let session: DeviceSession
    let isCurrent: Bool
    let onSignOut: () -> Void
    @Environment(\.theme) private var theme

    private var isComputer: Bool {
        for text in [session.deviceName, session.userAgent] {
            if let text, text.contains("Mac") || text.contains("Windows") || text.contains("Linux") {
                return true
            }
        }
        return false
    }

    private var subtitle: String {
        var parts: [String] = []
        if isCurrent {
            parts.append("To urządzenie")
        }
        if let city = session.city {
            parts.append(city)
        }
        if !isCurrent {
            parts.append(session.updatedAt.formatted(.relative(presentation: .named).locale(Locale(identifier: "pl"))))
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: Spacing.s12) {
            IconBadge(image: isComputer ? .laptopMac : .mobile, foreground: theme.accent, background: theme.accentTint)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.deviceName ?? "Nieznane urządzenie")
                    .typography(.bodyRegular)
                    .foregroundStyle(.neutralInk)
                Text(subtitle)
                    .typography(.footnote)
                    .foregroundStyle(.neutralGray)
            }
            Spacer(minLength: Spacing.s8)
            if isCurrent {
                Text("Aktywny")
                    .typography(.captionEmphasis)
                    .foregroundStyle(.statusSuccess)
                    .padding(.horizontal, Spacing.s8)
                    .padding(.vertical, Spacing.s4)
                    .background(.statusSuccessTint, in: .capsule)
            } else {
                Button("Wyloguj", action: onSignOut)
                    .typography(.subheadEmphasis)
                    .foregroundStyle(theme.accentStrong)
            }
        }
        .padding(.leading, Spacing.s14)
        .padding(.trailing, Spacing.s16)
        .padding(.vertical, Spacing.s12)
        .frame(minHeight: 58)
    }
}

private struct DangerRow: View {
    let icon: ImageResource
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                HStack(spacing: Spacing.s12) {
                    IconBadge(image: icon, foreground: .statusDanger, background: .statusDanger.opacity(0.1))
                    Text(title)
                        .typography(.bodyRegular)
                        .foregroundStyle(.statusDanger)
                    Spacer(minLength: 0)
                }
                .padding(.leading, Spacing.s14)
                .padding(.trailing, Spacing.s16)
                .padding(.vertical, Spacing.s12)
                .frame(minHeight: 58)
                .contentShape(.rect)
            }
        }
        .buttonStyle(.plain)
    }
}

struct SecurityView: View {
    let user: AuthUser
    @Environment(AuthStore.self) private var auth
    @Environment(\.theme) private var theme
    @State private var sessions: [DeviceSession]?
    @State private var isConfirmingSignOut = false
    @State private var isConfirmingDelete = false
    @State private var deletePassword = ""
    @State private var errorMessage = ""
    @State private var isShowingError = false

    init(user: AuthUser, sessions: [DeviceSession]? = nil) {
        self.user = user
        _sessions = State(initialValue: sessions)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.s24) {
                FormSection(title: "LOGOWANIE", separatorInset: 62) {
                    SettingsRow(icon: .mail, title: "E-mail") {
                        ChangeEmailView(user: user)
                    }
                    SettingsRow(icon: .key, title: "Hasło") {
                        ChangePasswordView()
                    }
                }

                FormSection(title: "URZĄDZENIA", separatorInset: 62) {
                    if let sessions {
                        ForEach(sessions) { session in
                            DeviceRow(session: session, isCurrent: auth.isCurrent(session)) {
                                run { try await auth.revoke(session) }
                            }
                        }
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 58)
                    }
                }

                VStack(spacing: Spacing.s8) {
                    ListCard(separatorInset: 62) {
                        DangerRow(icon: .logout, title: "Wyloguj ze wszystkich urządzeń") {
                            isConfirmingSignOut = true
                        }
                        DangerRow(icon: .delete, title: "Usuń konto") {
                            isConfirmingDelete = true
                        }
                    }
                    Text("Usunięcie konta jest nieodwracalne. W trwających wyjazdach Twoje wydatki zostaną, a Ty pojawisz się jako „Były uczestnik”.")
                        .typography(.footnote)
                        .foregroundStyle(.neutralGray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.s6)
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.s12)
            .padding(.bottom, 48)
        }
        .background { theme.background.ignoresSafeArea() }
        .navigationTitle("Bezpieczeństwo")
        .task {
            if sessions == nil {
                await load()
            }
        }
        .refreshable { await load() }
        .confirmationDialog("Wylogować ze wszystkich urządzeń?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
            Button("Wyloguj wszędzie", role: .destructive) {
                run { try await auth.signOutEverywhere() }
            }
        } message: {
            Text("Zostaniesz wylogowany również na tym urządzeniu.")
        }
        .alert("Usunąć konto?", isPresented: $isConfirmingDelete) {
            SecureField("Hasło", text: $deletePassword)
            Button("Usuń konto", role: .destructive) {
                let password = deletePassword
                deletePassword = ""
                run { try await auth.deleteAccount(password: password) }
            }
            Button("Anuluj", role: .cancel) { deletePassword = "" }
        } message: {
            Text("Wpisz hasło, aby potwierdzić. Tej operacji nie można cofnąć.")
        }
        .alert("Coś poszło nie tak", isPresented: $isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func load() async {
        do throws(AuthError) {
            sessions = try await auth.sessions().sorted { a, b in
                auth.isCurrent(a) || (!auth.isCurrent(b) && a.updatedAt > b.updatedAt)
            }
        } catch {
            errorMessage = error.localizedDescription
            isShowingError = true
        }
    }

    private func run(_ operation: @escaping () async throws -> Void) {
        Task {
            do {
                try await operation()
                await load()
            } catch {
                errorMessage = error.localizedDescription
                isShowingError = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        SecurityView(user: AuthUser(
            id: "preview",
            name: "Kuba",
            email: "kuba@zmykamy.pl",
            image: nil,
            themePalette: "ocean",
            termsVersion: AuthStore.currentTermsVersion,
            termsAcceptedAt: .now
        ), sessions: [
            DeviceSession(
                id: "1", token: "a", createdAt: .now, updatedAt: .now,
                userAgent: nil, deviceName: "iPhone 16 Pro", city: "Warszawa", countryCode: "PL"
            ),
            DeviceSession(
                id: "2", token: "b", createdAt: .now, updatedAt: .now.addingTimeInterval(-2 * 24 * 3600),
                userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Safari/605.1.15", deviceName: nil, city: "Kraków", countryCode: "PL"
            ),
            DeviceSession(
                id: "3", token: "c", createdAt: .now, updatedAt: .now.addingTimeInterval(-30 * 24 * 3600),
                userAgent: nil, deviceName: nil, city: nil, countryCode: nil
            ),
        ])
    }
    .environment(AuthStore())
}
