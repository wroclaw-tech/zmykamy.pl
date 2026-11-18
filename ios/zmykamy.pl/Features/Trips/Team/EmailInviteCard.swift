import SwiftUI

struct EmailInviteCard: View {
    let onSend: ([String]) async throws(APIError) -> EmailInviteResult
    @Environment(\.theme) private var theme
    @State private var text = ""
    @State private var message: (text: String, isError: Bool)?
    @State private var isSending = false
    @FocusState private var isFocused: Bool

    private var hasInput: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s16) {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text("Zaproś mailem")
                    .typography(.headline)
                    .foregroundStyle(.neutralInk)
                Text("Wpisz adresy e-mail oddzielone przecinkami. Wyślemy im link do wyjazdu.")
                    .typography(.subheadRegular)
                    .foregroundStyle(.neutralGray)
            }
            field
            Button(action: send) {
                Label("Wyślij zaproszenie", image: .mail)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .typography(.calloutEmphasis)
            .controlSize(.large)
            .disabled(!hasInput || isSending)
            if let message {
                Text(message.text)
                    .typography(.footnote)
                    .foregroundStyle(message.isError ? .statusDanger : .neutralGray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.neutralWhite, in: .rect(cornerRadius: Radius.xl))
    }

    private var field: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s8) {
            Image(.mail)
                .foregroundStyle(isFocused ? theme.accentStrong : .neutralGray)
            TextField("Adresy e-mail", text: $text, prompt: Text("ola@przyklad.pl, tomek@przyklad.pl"), axis: .vertical)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)
                .lineLimit(1...4)
                .focused($isFocused)
                .foregroundStyle(.neutralInk)
        }
        .typography(.calloutRegular)
        .padding(.horizontal, Spacing.s14)
        .padding(.vertical, Spacing.s12)
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
        .background(.alphaFill, in: .rect(cornerRadius: Radius.sm))
    }

    private func send() {
        let parsed = EmailAddresses.parse(text)
        if !parsed.invalid.isEmpty {
            message = ("Popraw \(parsed.invalid.count == 1 ? "adres" : "adresy"): \(parsed.invalid.joined(separator: ", ")).", true)
            return
        }
        if parsed.valid.count > EmailAddresses.maxPerRequest {
            message = ("Możesz wysłać maksymalnie \(EmailAddresses.maxPerRequest) zaproszeń naraz.", true)
            return
        }
        isSending = true
        Task {
            do throws(APIError) {
                let result = try await onSend(parsed.valid)
                text = ""
                isFocused = false
                message = (result.summary, !result.failed.isEmpty)
            } catch {
                message = (error.localizedDescription, true)
            }
            isSending = false
        }
    }
}

struct EmailInviteRow: View {
    let invite: EmailInvite
    let isResending: Bool
    let onResend: () -> Void
    @Environment(\.theme) private var theme

    private var subtitle: String {
        switch invite.status {
        case .sent: "Zaproszenie wysłane \(NoteFormat.relative(invite.sentAt) ?? "")"
        case .joined: "Dołączył(a) do ekipy"
        }
    }

    var body: some View {
        HStack(spacing: Spacing.s12) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                Text(invite.email)
                    .typography(.bodyEmphasis)
                    .foregroundStyle(.neutralInk)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle)
                    .typography(.footnote)
                    .foregroundStyle(.neutralGray)
            }
            Spacer(minLength: Spacing.s8)
            if invite.status == .sent {
                Button(action: onResend) {
                    Text("Szturchnij")
                        .typography(.subheadEmphasis)
                        .foregroundStyle(theme.accentStrong)
                        .padding(.horizontal, Spacing.s12)
                        .frame(height: 32)
                        .background(theme.background, in: .capsule)
                }
                .buttonStyle(.plain)
                .disabled(isResending)
                .opacity(isResending ? 0.5 : 1)
                .accessibilityLabel("Wyślij ponownie zaproszenie do \(invite.email)")
            }
        }
        .padding(.horizontal, Spacing.s14)
        .padding(.vertical, Spacing.s12)
        .contentShape(.rect)
    }

    @ViewBuilder
    private var icon: some View {
        switch invite.status {
        case .sent:
            Image(.schedule)
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundStyle(.neutralGray)
                .frame(width: 42, height: 42)
                .overlay {
                    Circle().strokeBorder(.neutralGray3, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
                .accessibilityHidden(true)
        case .joined:
            Image(.check)
                .foregroundStyle(.statusSuccess)
                .frame(width: 42, height: 42)
                .background(.statusSuccessTint, in: .circle)
                .accessibilityHidden(true)
        }
    }
}
