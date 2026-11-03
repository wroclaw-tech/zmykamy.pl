import SwiftUI

struct DashedAddButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s6) {
                Image(.addRounded)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text(title)
                    .typography(.bodyEmphasis)
            }
            .foregroundStyle(theme.accentStrong)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md)
                    .strokeBorder(theme.accent.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
