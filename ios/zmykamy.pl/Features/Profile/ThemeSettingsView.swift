import SwiftUI

struct ThemeSettingsView: View {
    let current: VacationClimate
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var selection: VacationClimate?
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var isShowingError = false

    init(current: VacationClimate) {
        self.current = current
        _selection = State(initialValue: current)
    }

    private var theme: Theme {
        (selection ?? current).theme
    }

    private var message: String {
        guard let selection, selection != current else { return "Twój kolor: \(current.colorName)" }
        return "Twój kolor: \(selection.colorName) (wcześniej \(current.colorName))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s20) {
                VStack(alignment: .leading, spacing: Spacing.s6) {
                    Text("Zmień kolorystykę")
                        .typography(Typography(size: 32, weight: .heavy, tracking: -1))
                        .foregroundStyle(.neutralInk)
                    Text("Wybierz klimat, a dopasujemy do niego kolory w całej aplikacji. Zmiana dotyczy tylko Twojego konta.")
                        .typography(.bodyRegular)
                        .foregroundStyle(.neutralInk2)
                }
                .padding(.horizontal, Spacing.s4)

                ClimateGrid(selection: $selection)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.s12)
            .padding(.bottom, Spacing.s16)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            ClimateSummaryBar(
                theme: theme,
                message: message,
                buttonTitle: "Zapisz kolorystykę",
                isEnabled: selection != current && !isSaving,
                action: save
            )
        }
        .background { theme.accentTint.ignoresSafeArea() }
        .environment(\.theme, theme)
        .tint(theme.accent)
        .alert("Nie udało się zapisać", isPresented: $isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func save() {
        guard let selection else { return }
        isSaving = true
        Task {
            do throws(AuthError) {
                try await auth.updateUser(UpdateUserRequest(themePalette: selection.rawValue))
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isShowingError = true
            }
            isSaving = false
        }
    }
}

#Preview {
    NavigationStack {
        ThemeSettingsView(current: .ocean)
    }
    .environment(AuthStore())
}
