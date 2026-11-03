import SwiftUI

/// One plan point on the day timeline: time, marker on the line, and a card.
struct PlanTimelineRow: View {
    let point: PlanPoint
    let isLast: Bool
    let isEditable: Bool
    let onTap: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s8) {
            Text(point.time.text)
                .typography(.calloutEmphasis)
                .monospacedDigit()
                .foregroundStyle(.neutralInk2)
                .frame(width: 46, alignment: .leading)
                .padding(.top, Spacing.s14)
            marker
            Button(action: onTap) {
                card
            }
            .buttonStyle(.plain)
            .disabled(!isEditable)
            .padding(.bottom, isLast ? 0 : Spacing.s12)
        }
    }

    private var marker: some View {
        ZStack(alignment: .top) {
            if !isLast {
                Rectangle()
                    .fill(theme.accent.opacity(0.25))
                    .frame(width: 2)
                    .padding(.top, 26)
            }
            Circle()
                .fill(theme.accentTint)
                .frame(width: 16, height: 16)
                .overlay {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 10, height: 10)
                }
                .padding(.top, 15)
        }
        .frame(width: 16)
        .frame(maxHeight: .infinity)
    }

    private var card: some View {
        HStack(alignment: .top, spacing: Spacing.s12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(point.title)
                    .typography(.bodyEmphasis)
                    .foregroundStyle(.neutralInk)
                    .multilineTextAlignment(.leading)
                if let subtitle = point.subtitle {
                    Text(subtitle)
                        .typography(.subheadRegular)
                        .foregroundStyle(.neutralGray)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: Spacing.s8)
            Image(point.icon.resource)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(theme.accent)
        }
        .padding(Spacing.s14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.neutralWhite, in: .rect(cornerRadius: Radius.md))
        .contentShape(.rect(cornerRadius: Radius.md))
    }
}
