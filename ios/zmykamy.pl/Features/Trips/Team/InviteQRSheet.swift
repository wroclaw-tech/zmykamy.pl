import SwiftUI

struct InviteQRSheet: View {
    let tripName: String
    let invite: TripInvite
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.s16) {
                if let image = QRCode.image(for: invite.url.absoluteString) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 240, height: 240)
                        .padding(Spacing.s16)
                        .background(.neutralWhite, in: .rect(cornerRadius: Radius.md))
                        .accessibilityLabel("Kod QR z zaproszeniem")
                }
                VStack(spacing: Spacing.s4) {
                    Text(tripName)
                        .typography(.title2)
                        .foregroundStyle(.neutralInk)
                    Text(invite.displayLink)
                        .typography(.subheadRegular)
                        .foregroundStyle(.neutralGray)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { theme.background.ignoresSafeArea() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Zamknij", image: .close) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

extension TripInvite {
    /// The link without its scheme, as shown in the app.
    var displayLink: String {
        url.absoluteString.replacing(/^https?:\/\//, with: "")
    }
}
