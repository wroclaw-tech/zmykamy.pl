import SwiftUI

struct ThemePreview: View {
    let theme: Theme?
    var size: CGFloat = 24

    var body: some View {
        HStack(spacing: -size / 4) {
            dot(theme?.accent ?? .neutralGray3)
            dot(theme?.accentTint ?? Color(red: 0.898, green: 0.898, blue: 0.918))
        }
    }

    private func dot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .overlay { Circle().strokeBorder(.neutralWhite, lineWidth: 2) }
            .frame(width: size, height: size)
    }
}
