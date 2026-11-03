import SwiftUI

struct ProgressBar<Track: ShapeStyle>: View {
    let done: Int
    let total: Int
    let track: Track
    @Environment(\.theme) private var theme

    private var fraction: CGFloat {
        total == 0 ? 0 : CGFloat(done) / CGFloat(total)
    }

    var body: some View {
        Capsule()
            .fill(track)
            .frame(height: 8)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(theme.accent)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .clipShape(.capsule)
            .accessibilityElement()
            .accessibilityValue("\(done) z \(total)")
    }
}
