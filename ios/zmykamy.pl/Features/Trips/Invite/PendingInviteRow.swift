import SwiftUI

struct PendingInviteRow: View {
    let invite: PendingEmailInvite
    @Environment(\.theme) private var theme

    private var subtitle: String {
        [
            invite.inviterName.map { "\($0) zaprasza" },
            TripDateFormat.shortRange(invite.trip.startDate, invite.trip.endDate, includesYear: false),
        ]
        .compactMap(\.self)
        .joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(.mail)
                .foregroundStyle(theme.accent)
                .frame(width: 54, height: 54)
                .background(theme.accentTint, in: .rect(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text(invite.trip.name)
                    .typography(Typography(size: 17, weight: .semibold))
                    .foregroundStyle(.neutralInk)
                Text(subtitle)
                    .typography(.subheadRegular)
                    .foregroundStyle(.neutralGray)
            }
            Spacer(minLength: Spacing.s8)
            Image(.chevronRight)
                .foregroundStyle(.neutralGray)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, Spacing.s12)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Otwiera zaproszenie do wyjazdu")
    }
}
