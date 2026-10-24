import SwiftUI

struct LabeledField: View {
    let label: String
    @Binding var text: String
    var prompt: String?
    var isMonospaced = false
    var isSecure = false
    @Environment(\.theme) private var theme
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .typography(.captionRegular)
                .foregroundStyle(isFocused ? AnyShapeStyle(theme.accentStrong) : AnyShapeStyle(.neutralGray))
            Group {
                if isSecure {
                    SecureField(label, text: $text, prompt: prompt.map { Text($0) })
                } else {
                    TextField(label, text: $text, prompt: prompt.map { Text($0) })
                }
            }
                .typography(.bodyLarge)
                .monospaced(isMonospaced)
                .foregroundStyle(.neutralInk)
                .focused($isFocused)
        }
        .padding(.horizontal, Spacing.s16)
        .padding(.vertical, Spacing.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isFocused ? theme.accentTint : .clear)
        .contentShape(.rect)
        .onTapGesture { isFocused = true }
    }
}
