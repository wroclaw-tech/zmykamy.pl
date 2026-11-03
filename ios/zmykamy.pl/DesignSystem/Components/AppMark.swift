import SwiftUI

struct AppMark: View {
    var size: CGFloat = 38
    @Environment(\.theme) private var theme

    var body: some View {
        Canvas { context, canvas in
            let scale = canvas.width / 180
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            context.stroke(
                Self.letter.applying(transform),
                with: .color(.neutralWhite),
                style: StrokeStyle(lineWidth: 20 * scale, lineCap: .round, lineJoin: .round)
            )
            let pin = Self.pin.applying(transform)
            context.stroke(pin, with: .color(theme.accent), lineWidth: 7 * scale)
            context.fill(pin, with: .color(.neutralWhite))
            context.fill(
                Path(ellipseIn: CGRect(x: 121, y: 83, width: 18, height: 18)).applying(transform),
                with: .color(theme.accent)
            )
        }
        .frame(width: size, height: size)
        .background(theme.accent, in: .rect(cornerRadius: size * 0.225, style: .continuous))
        .accessibilityHidden(true)
    }

    private static let letter = Path { path in
        path.move(to: CGPoint(x: 38, y: 60))
        path.addLine(to: CGPoint(x: 98, y: 60))
        path.addLine(to: CGPoint(x: 44, y: 116))
        path.addLine(to: CGPoint(x: 98, y: 116))
    }

    private static let pin = Path { path in
        path.move(to: CGPoint(x: 130, y: 129.2))
        path.addCurve(to: CGPoint(x: 106, y: 92), control1: CGPoint(x: 122.8, y: 119.12), control2: CGPoint(x: 106, y: 111.2))
        path.addCurve(to: CGPoint(x: 130, y: 68), control1: CGPoint(x: 106, y: 78.745), control2: CGPoint(x: 116.745, y: 68))
        path.addCurve(to: CGPoint(x: 154, y: 92), control1: CGPoint(x: 143.255, y: 68), control2: CGPoint(x: 154, y: 78.745))
        path.addCurve(to: CGPoint(x: 130, y: 129.2), control1: CGPoint(x: 154, y: 111.2), control2: CGPoint(x: 137.2, y: 119.12))
        path.closeSubpath()
    }
}

#Preview {
    HStack(spacing: Spacing.s16) {
        AppMark(size: 38)
        AppMark(size: 64)
        AppMark(size: 120)
            .environment(\.theme, .terakota)
    }
    .padding()
}
