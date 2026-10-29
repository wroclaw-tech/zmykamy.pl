import SwiftUI

struct MemberRow: View {
    let member: TripMember
    let isViewer: Bool
    let currency: String
    @Environment(\.theme) private var theme

    private var balanceColor: Color {
        switch member.balance {
        case ..<0: .statusDanger
        case 0: .neutralGray
        default: .statusSuccess
        }
    }

    var body: some View {
        HStack(spacing: Spacing.s12) {
            Text(member.initial)
                .typography(.headline)
                .foregroundStyle(.neutralWhite)
                .frame(width: 42, height: 42)
                .background(isViewer ? theme.accent : member.avatarColor, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(isViewer ? "\(member.name) (Ty)" : member.name)
                    .typography(.bodyEmphasis)
                    .foregroundStyle(.neutralInk)
                if member.role == .organizer {
                    Text("Organizator")
                        .typography(.captionRegular)
                        .foregroundStyle(.neutralGray)
                }
            }
            Spacer(minLength: Spacing.s8)
            Text(BalanceFormat.string(minorUnits: member.balance, currency: currency))
                .typography(.subheadEmphasis)
                .foregroundStyle(balanceColor)
        }
        .padding(.horizontal, Spacing.s14)
        .padding(.vertical, Spacing.s12)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
