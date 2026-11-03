import SwiftUI

struct PrimaryButton: View {
    let title: String
    var icon: ImageResource?
    var isEnabled = true
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s6) {
                Text(title)
                    .typography(.headline)
                if let icon {
                    Image(icon)
                }
            }
            .foregroundStyle(.neutralWhite)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(theme.accent.opacity(isEnabled ? 1 : 0.4), in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
