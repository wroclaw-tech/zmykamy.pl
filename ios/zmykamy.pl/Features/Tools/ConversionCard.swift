import SwiftUI

/// Shared two-row layout from the saved currency and unit converter references.
struct ConversionCard<Source: View, Target: View>: View {
    @ViewBuilder var source: Source
    @ViewBuilder var target: Target
    let swap: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            source.frame(minHeight: 84)
            target.frame(minHeight: 84)
        }
        .padding(.horizontal, Spacing.s14)
        .background(.neutralWhite, in: .rect(cornerRadius: Radius.xl))
        .overlay {
            HStack(spacing: Spacing.s8) {
                Rectangle().fill(.alphaSeparator).frame(height: 0.5)
                Button(action: swap) {
                    Image(.swapVert).resizable().scaledToFit().frame(width: 20, height: 20)
                        .foregroundStyle(.neutralWhite)
                        .frame(width: 36, height: 36)
                        .background(theme.accent, in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Zamień kierunek przeliczania")
            }
            .padding(.leading, 62)
            .padding(.trailing, Spacing.s14)
        }
    }
}

struct ConversionBadge: View {
    let text: String
    @Environment(\.theme) private var theme
    var body: some View {
        Text(text).typography(.subheadEmphasis)
            .foregroundStyle(theme.accentStrong)
            .frame(width: 40, height: 40)
            .background(theme.accentTint, in: .circle)
            .accessibilityHidden(true)
    }
}
