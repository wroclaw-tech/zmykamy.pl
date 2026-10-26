import SwiftUI

struct ClimateView: View {
    @Binding var selection: VacationClimate?
    let onContinue: () -> Void
    let onSkip: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.s20) {
                OnboardingStepHeader(
                    step: 2,
                    stepCount: 3,
                    title: "Z czym kojarzą Ci się wakacje?",
                    subtitle: "Wybierz jedną opcję, a dopasujemy do niej kolorystykę aplikacji. Możesz ją zmienić w Ustawieniach.",
                    onSkip: onSkip
                )

                ClimateGrid(selection: $selection)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.s12)
            .padding(.bottom, Spacing.s16)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            ClimateSummaryBar(
                theme: selection == nil ? nil : theme,
                message: selection.map { "Twój kolor: \($0.colorName)" } ?? "Kolorystyka zostanie dopasowana do wyboru",
                buttonTitle: selection == nil ? "Wybierz opcję" : "Dalej",
                buttonImage: .arrowForward,
                isEnabled: selection != nil,
                action: onContinue
            )
        }
        .background {
            (selection == nil ? theme.background : theme.accentTint)
                .ignoresSafeArea()
        }
    }
}

#Preview {
    @Previewable @State var selection: VacationClimate?
    ClimateView(selection: $selection, onContinue: {}, onSkip: {})
        .environment(\.theme, selection?.theme ?? .ocean)
}
