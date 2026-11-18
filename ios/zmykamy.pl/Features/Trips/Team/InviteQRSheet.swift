import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

struct InviteQRSheet: View {
    let trip: Trip
    let invite: TripInvite
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.s16) {
                if let image = QRCode.image(for: invite.url.absoluteString) {
                    InviteQRCodeView(image: image)
                        .accessibilityLabel("Kod QR z zaproszeniem")
                }
                VStack(spacing: Spacing.s4) {
                    Text(trip.name)
                        .typography(.title2)
                        .foregroundStyle(.neutralInk)
                    Text(invite.displayLink)
                        .typography(.subheadRegular)
                        .foregroundStyle(.neutralGray)
                }
                shareButton
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { theme.background.ignoresSafeArea() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Zamknij", image: .close) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private var shareButton: some View {
        if let image = InviteQRShareImage(url: invite.url) {
            ShareLink(
                item: image,
                subject: Text(trip.name),
                message: Text(invite.shareMessage(for: trip)),
                preview: SharePreview(trip.name, image: Image(uiImage: image.image))
            ) {
                Label("Udostępnij", image: .iosShare)
                    .typography(.calloutEmphasis)
                    .frame(maxWidth: 240)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(theme.accent)
            .padding(.top, Spacing.s8)
        }
    }
}

/// The QR code on a white card with a quiet zone, as shown in the app and in the shared image.
private struct InviteQRCodeView: View {
    let image: UIImage

    var body: some View {
        Image(uiImage: image)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: 240, height: 240)
            .padding(Spacing.s16)
            .background(.neutralWhite, in: .rect(cornerRadius: Radius.md))
    }
}

/// The invite QR code as a PNG, so the share sheet offers messaging apps and "Save Image".
struct InviteQRShareImage: Transferable {
    let image: UIImage

    @MainActor
    init?(url: URL) {
        guard let code = QRCode.image(for: url.absoluteString) else { return nil }
        let renderer = ImageRenderer(content: InviteQRCodeView(image: code).environment(\.colorScheme, .light))
        renderer.scale = 3
        guard let image = renderer.uiImage else { return nil }
        self.image = image
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            guard let data = item.image.pngData() else { throw CocoaError(.fileWriteUnknown) }
            return data
        }
        .suggestedFileName("zmykamy-zaproszenie.png")
    }
}

extension TripInvite {
    /// Text sent along with the QR code when sharing the invite.
    func shareMessage(for trip: Trip) -> String {
        let target = trip.destination.map { "do \($0.name)" } ?? "„\(trip.name)”"
        return "Dołącz do mojej wycieczki \(target) na zmykamy.pl! \(url.absoluteString)"
    }

    /// The link without its scheme, as shown in the app.
    var displayLink: String {
        url.absoluteString.replacing(/^https?:\/\//, with: "")
    }
}
