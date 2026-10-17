import SwiftUI

enum AuthMode: CaseIterable, Identifiable {
    case signIn
    case signUp

    var id: Self { self }

    var title: String {
        switch self {
        case .signIn: "Logowanie"
        case .signUp: "Rejestracja"
        }
    }
}

private struct AuthAlert {
    let title: String
    let message: String
}

private enum AuthField: Hashable {
    case name
    case email
    case password
}

private struct FieldRow<Field: View>: View {
    let icon: ImageResource
    @ViewBuilder let field: Field

    var body: some View {
        HStack(spacing: Spacing.s12) {
            Image(icon)
                .resizable()
                .frame(width: 21, height: 21)
                .foregroundStyle(.neutralGray)
                .accessibilityHidden(true)
            field
                .typography(.bodyLarge)
                .foregroundStyle(.neutralInk)
        }
        .padding(.horizontal, Spacing.s16)
        .frame(height: 52)
    }
}

private struct SocialButton: View {
    let title: String
    let logo: ImageResource
    let isDark: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(logo)
                    .resizable()
                    .frame(width: 18, height: 18)
                Text(title)
                    .typography(.calloutEmphasis)
            }
            .foregroundStyle(isDark ? .neutralWhite : .neutralInk)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(isDark ? .neutralBlack : .neutralWhite, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}

struct AuthView: View {
    let climate: VacationClimate?
    @State private var mode: AuthMode
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var alert: AuthAlert?
    @FocusState private var focusedField: AuthField?
    @Environment(AuthStore.self) private var auth
    @Environment(\.theme) private var theme

    init(mode: AuthMode, climate: VacationClimate?) {
        self.climate = climate
        _mode = State(initialValue: mode)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canSubmit: Bool {
        let emailIsValid = trimmedEmail.wholeMatch(of: /[^@\s]+@[^@\s]+\.[^@\s]+/) != nil
        switch mode {
        case .signIn:
            return emailIsValid && !password.isEmpty
        case .signUp:
            return emailIsValid
                && (1...60).contains(trimmedName.count)
                && password.count >= AuthClient.minPasswordLength
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.top, 56)
                    Spacer(minLength: Spacing.s24)
                    card
                        .padding(.bottom, Spacing.s6)
                }
                .padding(.horizontal, Spacing.s20)
                .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
        .background { GradientAuth() }
        .alert(
            alert?.title ?? "",
            isPresented: Binding(get: { alert != nil }, set: { if !$0 { alert = nil } }),
            presenting: alert
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.s14) {
            Text("zmykamy\(Text(".pl").foregroundStyle(theme.accent))")
                .typography(.displayLogo)
                .foregroundStyle(.neutralInk)
            Text("Plan podróży, wspólne wydatki, uczestnicy i zdjęcia w jednym miejscu.")
                .typography(Typography(size: 22, weight: .semibold, tracking: -0.4))
                .foregroundStyle(.neutralInk)
                .frame(maxWidth: 320, alignment: .leading)
        }
        .padding(.horizontal, Spacing.s6)
    }

    private var card: some View {
        VStack(spacing: 0) {
            Picker("Tryb", selection: $mode.animation(.snappy)) {
                ForEach(AuthMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.large)
            .labelsHidden()

            fields
                .padding(.top, Spacing.s12)

            submitButton
                .padding(.top, Spacing.s12)

            HStack(spacing: 10) {
                divider
                Text("albo")
                    .typography(.footnote)
                    .foregroundStyle(.neutralGray)
                divider
            }
            .padding(.top, Spacing.s20)

            HStack(spacing: 10) {
                SocialButton(title: "Apple", logo: .appleLogo, isDark: true) { showComingSoon("Apple") }
                SocialButton(title: "Google", logo: .googleLogo, isDark: false) { showComingSoon("Google") }
            }
            .padding(.top, Spacing.s20)

            footer
                .padding(.top, Spacing.s14)
        }
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 36))
    }

    private var fields: some View {
        VStack(spacing: 0) {
            if mode == .signUp {
                FieldRow(icon: .person) {
                    TextField("Jak cię wołają?", text: $name)
                        .textContentType(.givenName)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .name)
                        .onSubmit { focusedField = .email }
                }
                separator
            }
            FieldRow(icon: .mail) {
                TextField("E-mail", text: $email)
                    .textContentType(mode == .signUp ? .emailAddress : .username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focusedField, equals: .email)
                    .onSubmit { focusedField = .password }
            }
            separator
            FieldRow(icon: .lock) {
                SecureField(mode == .signUp ? "Hasło (min. \(AuthClient.minPasswordLength) znaków)" : "Hasło", text: $password)
                    .textContentType(mode == .signUp ? .newPassword : .password)
                    .submitLabel(.go)
                    .focused($focusedField, equals: .password)
                    .onSubmit(submit)
            }
        }
        .background(.neutralWhite.opacity(0.8), in: .rect(cornerRadius: Radius.md))
    }

    private var submitButton: some View {
        Button(action: submit) {
            HStack(spacing: Spacing.s6) {
                if isSubmitting {
                    ProgressView()
                        .tint(.neutralWhite)
                } else {
                    Text(mode == .signUp ? "Utwórz konto" : "Zaloguj się")
                    Image(.arrowForward)
                        .resizable()
                        .frame(width: 20, height: 20)
                }
            }
            .typography(.headline)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.extraLarge)
        .tint(theme.accent)
        .disabled(!canSubmit || isSubmitting)
        .shadow(color: theme.accent.opacity(canSubmit ? 0.35 : 0), radius: 10, y: 8)
    }

    @ViewBuilder
    private var footer: some View {
        switch mode {
        case .signUp:
            Text("Tworząc konto, akceptujesz regulamin.")
                .typography(.footnote)
                .foregroundStyle(.neutralGray)
        case .signIn:
            HStack(spacing: Spacing.s4) {
                Text("Nie pamiętasz hasła?")
                    .foregroundStyle(.neutralGray)
                Button("Zresetuj je.") {
                    alert = AuthAlert(title: "Reset hasła", message: "Reset hasła będzie dostępny wkrótce.")
                }
                .foregroundStyle(theme.accentStrong)
            }
            .typography(.footnote)
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(.neutralInk2.opacity(0.18))
            .frame(height: 0.5)
    }

    private var divider: some View {
        Rectangle()
            .fill(.neutralInk2.opacity(0.25))
            .frame(height: 0.5)
    }

    private func showComingSoon(_ provider: String) {
        alert = AuthAlert(title: "Już wkrótce", message: "Logowanie przez \(provider) będzie dostępne wkrótce.")
    }

    private func submit() {
        guard canSubmit, !isSubmitting else { return }
        focusedField = nil
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do throws(AuthError) {
                switch mode {
                case .signIn:
                    try await auth.signIn(email: trimmedEmail, password: password)
                case .signUp:
                    try await auth.signUp(
                        name: trimmedName,
                        email: trimmedEmail,
                        password: password,
                        themePalette: climate?.rawValue
                    )
                }
            } catch {
                let failedMode = mode
                if error == .userAlreadyExists {
                    withAnimation(.snappy) { mode = .signIn }
                }
                alert = AuthAlert(
                    title: failedMode == .signUp ? "Nie udało się utworzyć konta" : "Nie udało się zalogować",
                    message: error.localizedDescription
                )
            }
        }
    }
}

#Preview {
    AuthView(mode: .signUp, climate: .ocean)
        .environment(AuthStore())
}
