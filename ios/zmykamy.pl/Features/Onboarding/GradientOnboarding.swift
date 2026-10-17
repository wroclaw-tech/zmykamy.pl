import SwiftUI

struct GradientOnboarding: View {
    @Environment(\.theme) private var theme

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                theme.background
                gradientBlob(color: theme.accent.opacity(0.3), radius: (0.66, 0.30), center: (0.10, 0.00), in: size)
                gradientBlob(color: theme.accent.opacity(0.4), radius: (0.52, 0.29), center: (1.00, 0.20), in: size)
            }
        }
        .ignoresSafeArea()
    }
}

/// Glow from `color` to transparent.
///
/// - Parameters:
///   - color: color at the centre
///   - radius: x,y sizes, as fractions of width and height.
///   - center: centre point, `(0, 0)` =  top-left, `(1, 1)` =  bottom-right.
///   - size: size of the parent container
private func gradientBlob(
    color: Color,
    radius: (x: CGFloat, y: CGFloat),
    center: (x: CGFloat, y: CGFloat),
    in size: CGSize
) -> some View {
    EllipticalGradient(colors: [color, color.opacity(0)])
        .frame(width: size.width * radius.x * 2, height: size.height * radius.y * 2)
        .position(x: size.width * center.x, y: size.height * center.y)
}
