import SwiftUI

enum InviteState: Equatable {
    case loading
    case loaded(TripInvite)
    case failed
}

struct InviteCard: View {
    let tripName: String
    let state: InviteState
    let canRegenerate: Bool
    let onShowQR: () -> Void
    let onRegenerate: () -> Void
    let onRetry: () -> Void
    @Environment(\.theme) private var theme
    @State private var didCopy = false

    private var invite: TripInvite? {
        if case .loaded(let invite) = state { invite } else { nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s16) {
            header
            linkField
            actions
            if canRegenerate {
                Button("Wygeneruj nowy link", action: onRegenerate)
                    .typography(.footnote)
                    .foregroundStyle(.neutralGray)
                    .disabled(invite == nil)
            }
        }
        .padding(Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.neutralWhite, in: .rect(cornerRadius: Radius.xl))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.s12) {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text("Zaproś uczestników")
                    .typography(.headline)
                    .foregroundStyle(.neutralInk)
                Text("Udostępnij link z zaproszeniem. Każdy, kto go otworzy, może dołączyć do wyjazdu.")
                    .typography(.subheadRegular)
                    .foregroundStyle(.neutralGray)
            }
            Spacer(minLength: 0)
            Button(action: onShowQR) {
                Image(systemName: "qrcode")
                    .font(.system(size: 22))
                    .foregroundStyle(theme.accent)
                    .frame(width: 52, height: 52)
                    .background(theme.accent.opacity(0.12), in: .rect(cornerRadius: Radius.sm))
            }
            .buttonStyle(.plain)
            .disabled(invite == nil)
            .accessibilityLabel("Pokaż kod QR")
        }
    }

    @ViewBuilder
    private var linkField: some View {
        HStack(spacing: Spacing.s8) {
            Image(systemName: "link")
                .foregroundStyle(.neutralGray)
            switch state {
            case .loading:
                Text("Ładowanie linku…")
                    .foregroundStyle(.neutralGray)
            case .loaded(let invite):
                Text(invite.displayLink)
                    .foregroundStyle(.neutralInk)
                    .textSelection(.enabled)
            case .failed:
                Text("Nie udało się wczytać linku")
                    .foregroundStyle(.neutralGray)
                Spacer(minLength: 0)
                Button("Ponów", action: onRetry)
            }
        }
        .typography(.calloutRegular)
        .lineLimit(1)
        .padding(.horizontal, Spacing.s14)
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
        .background(.alphaFill, in: .rect(cornerRadius: Radius.sm))
    }

    private var actions: some View {
        HStack(spacing: Spacing.s8) {
            Button(action: copy) {
                Label(didCopy ? "Skopiowano" : "Kopiuj link", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            if let invite {
                ShareLink(item: invite.url, message: Text("Dołącz do wyjazdu „\(tripName)” w Zmykamy")) {
                    Label("Udostępnij", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
            } else {
                Button {} label: {
                    Label("Udostępnij", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
            }
        }
        .typography(.calloutEmphasis)
        .controlSize(.large)
        .disabled(invite == nil)
    }

    private func copy() {
        guard let invite else { return }
        UIPasteboard.general.string = invite.url.absoluteString
        didCopy = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            didCopy = false
        }
    }
}
