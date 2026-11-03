import SwiftUI

struct CheckToggle: View {
    let isOn: Bool
    var size: CGFloat = 26
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Group {
                if isOn {
                    Image(.checkCircle)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(theme.accent)
                } else {
                    Image(.radioButtonUnchecked)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.neutralGray3)
                }
            }
            .frame(width: size, height: size)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "Odznacz" : "Zaznacz")
    }
}
