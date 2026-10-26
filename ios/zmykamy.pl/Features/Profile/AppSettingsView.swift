import SwiftUI

private struct SettingOption: Identifiable {
    let id: String
    let title: String
}

private struct MenuRow: View {
    let icon: ImageResource
    let title: String
    let options: [SettingOption]
    let selection: String
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
            Picker(title, selection: Binding(get: { selection }, set: onSelect)) {
                ForEach(options) { option in
                    Text(option.title).tag(option.id)
                }
            }
        } label: {
            SettingsRowLabel(icon: icon, title: title, value: options.first { $0.id == selection }?.title ?? selection)
        }
        .buttonStyle(.plain)
    }
}

struct AppSettingsView: View {
    let user: AuthUser
    @Environment(AuthStore.self) private var auth
    @Environment(\.theme) private var theme
    @State private var errorMessage = ""
    @State private var isShowingError = false

    private static let languages = [
        SettingOption(id: "pl", title: "Polski"),
        SettingOption(id: "en", title: "English"),
    ]

    private static let currencies = [
        SettingOption(id: "PLN", title: "PLN · zł"),
        SettingOption(id: "EUR", title: "EUR · €"),
        SettingOption(id: "USD", title: "USD · $"),
        SettingOption(id: "GBP", title: "GBP · £"),
        SettingOption(id: "CZK", title: "CZK · Kč"),
    ]

    private static let dateFormats = ["dd.MM.yyyy", "yyyy-MM-dd", "dd/MM/yyyy", "MM/dd/yyyy"].map { pattern in
        let formatter = DateFormatter()
        formatter.dateFormat = pattern
        return SettingOption(id: pattern, title: formatter.string(from: .now))
    }

    private static let weekStarts = [
        SettingOption(id: "monday", title: "poniedziałek"),
        SettingOption(id: "sunday", title: "niedziela"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.s24) {
                FormSection(
                    title: "OGÓLNE",
                    footnote: "Waluta domyślna podpowiada się przy tworzeniu nowego wyjazdu.",
                    separatorInset: 62
                ) {
                    MenuRow(icon: .language, title: "Język", options: Self.languages, selection: user.language ?? "pl") {
                        save(UpdateUserRequest(language: $0))
                    }
                    MenuRow(icon: .payments, title: "Waluta domyślna", options: Self.currencies, selection: user.defaultCurrency ?? "PLN") {
                        save(UpdateUserRequest(defaultCurrency: $0))
                    }
                    MenuRow(icon: .calendarToday, title: "Format daty", options: Self.dateFormats, selection: user.dateFormat ?? "dd.MM.yyyy") {
                        save(UpdateUserRequest(dateFormat: $0))
                    }
                    MenuRow(icon: .eventNote, title: "Początek tygodnia", options: Self.weekStarts, selection: user.weekStart ?? "monday") {
                        save(UpdateUserRequest(weekStart: $0))
                    }
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.s12)
            .padding(.bottom, 48)
        }
        .background { theme.background.ignoresSafeArea() }
        .navigationTitle("Ustawienia")
        .alert("Nie udało się zapisać", isPresented: $isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func save(_ request: UpdateUserRequest) {
        Task {
            do throws(AuthError) {
                try await auth.updateUser(request)
            } catch {
                errorMessage = error.localizedDescription
                isShowingError = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        AppSettingsView(user: AuthUser(
            id: "preview",
            name: "Kubson",
            email: "kuba@zmykamy.pl",
            image: nil,
            themePalette: "ocean",
            termsVersion: AuthStore.currentTermsVersion,
            termsAcceptedAt: .now
        ))
    }
    .environment(AuthStore())
}
