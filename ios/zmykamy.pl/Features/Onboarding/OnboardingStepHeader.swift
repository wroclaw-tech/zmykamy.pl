import SwiftUI

struct OnboardingStepHeader: View {
    let step: Int
    let stepCount: Int
    let title: String
    let subtitle: String
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 5) {
                    ForEach(1...stepCount, id: \.self) { index in
                        Capsule()
                            .fill(index <= step ? AnyShapeStyle(.neutralInk) : AnyShapeStyle(.neutralInk2.opacity(0.2)))
                            .frame(width: 28, height: 5)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel("Krok \(step) z \(stepCount)")

                Spacer()

                Button("Pomiń", action: onSkip)
                    .typography(.bodyEmphasis)
                    .foregroundStyle(.neutralGray)
            }
            .padding(.horizontal, Spacing.s4)

            Text(title)
                .typography(Typography(size: 32, weight: .heavy, tracking: -1))
                .foregroundStyle(.neutralInk)
                .padding(.top, 28)

            Text(subtitle)
                .typography(.bodyRegular)
                .foregroundStyle(.neutralInk2)
                .padding(.top, Spacing.s6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.s4)
    }
}

#Preview {
    OnboardingStepHeader(
        step: 2,
        stepCount: 3,
        title: "Z czym kojarzą Ci się wakacje?",
        subtitle: "Wybierz jedną opcję, a dopasujemy do niej kolorystykę aplikacji.",
        onSkip: {}
    )
    .padding(.horizontal, Spacing.gutter)
}
