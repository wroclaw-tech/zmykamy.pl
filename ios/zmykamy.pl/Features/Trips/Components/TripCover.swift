import SwiftUI

/// The trip photo, or a gradient in the viewer's own theme when the trip has no photo.
struct TripCover: View {
    let url: URL?
    @Environment(\.theme) private var theme

    var body: some View {
        let gradient = LinearGradient(
            colors: [theme.accentTint, theme.accent, theme.accentStrong],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        Color.clear
            .overlay {
                if let url {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        gradient
                    }
                } else {
                    gradient
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }
}

#Preview {
    TripCover(url: nil)
        .frame(width: 200, height: 120)
}
