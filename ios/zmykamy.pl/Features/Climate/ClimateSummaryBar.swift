import SwiftUI

struct ClimateSummaryBar: View {
    let theme: Theme?
    let message: String
    let buttonTitle: String
    var buttonImage: ImageResource?
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: Spacing.s12) {
            HStack(spacing: 10) {
                ThemePreview(theme: theme)
                Text(message)
                    .typography(.subheadRegular)
                    .foregroundStyle(.neutralInk2)
                    .contentTransition(.opacity)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.s6)

            Button(action: action) {
                HStack(spacing: Spacing.s6) {
                    Text(buttonTitle)
                    if let buttonImage {
                        Image(buttonImage)
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                }
                .typography(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
            .tint(theme?.accent)
            .disabled(!isEnabled)
        }
        .padding(Spacing.s14)
        .glassEffect(.regular, in: .rect(cornerRadius: 34))
        .padding(.horizontal, Spacing.s12)
    }
}
