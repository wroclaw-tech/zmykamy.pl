import SwiftUI

struct ExpenseSummaryCard: View {
    let summary: ExpenseSummary
    let balance: Int?
    let currency: String
    let userID: String
    let onSettle: () -> Void
    @Environment(\.theme) private var theme

    private func color(for payer: ExpenseSummary.Payer) -> Color {
        payer.userId == userID ? theme.accent : AvatarColor.color(for: payer.userId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s16) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    Text("Łączne wydatki")
                        .typography(.subheadRegular)
                        .foregroundStyle(.neutralGray)
                    Text(MoneyFormat.string(minorUnits: summary.total, currency: currency))
                        .typography(Typography(size: 34, weight: .heavy, tracking: -1))
                        .foregroundStyle(.neutralInk)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                Spacer(minLength: Spacing.s8)
                VStack(alignment: .trailing, spacing: Spacing.s4) {
                    Text("Twoja część")
                        .typography(.subheadRegular)
                        .foregroundStyle(.neutralGray)
                    Text(MoneyFormat.precise(minorUnits: summary.myShare, currency: currency))
                        .typography(.headline)
                        .foregroundStyle(.neutralInk)
                }
            }

            if summary.total > 0 {
                payersBar
                FlowLayout(spacing: Spacing.s12, lineSpacing: Spacing.s6) {
                    ForEach(summary.payers) { payer in
                        HStack(spacing: Spacing.s4) {
                            Circle()
                                .fill(color(for: payer))
                                .frame(width: 7, height: 7)
                            Text("\(payer.userId == userID ? "Ty" : payer.name) \(MoneyFormat.string(minorUnits: payer.amount, currency: currency))")
                                .typography(.captionRegular)
                                .foregroundStyle(.neutralInk2)
                        }
                    }
                }
            }

            balanceBox
        }
        .padding(Spacing.s20)
        .background(.neutralWhite, in: .rect(cornerRadius: Radius.xl))
    }

    private var payersBar: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 2
            let available = proxy.size.width - spacing * CGFloat(max(summary.payers.count - 1, 0))
            HStack(spacing: spacing) {
                ForEach(summary.payers) { payer in
                    Capsule()
                        .fill(color(for: payer))
                        .frame(width: max(available * CGFloat(payer.amount) / CGFloat(summary.total), 4))
                }
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }

    private var balanceBox: some View {
        HStack(spacing: Spacing.s12) {
            VStack(alignment: .leading, spacing: 2) {
                if let balance {
                    Text(balance < 0 ? "Do zapłaty" : balance > 0 ? "Do odebrania" : "Saldo")
                        .typography(.footnote)
                        .foregroundStyle(.neutralGray)
                    Text(balance == 0 ? "Rozliczone" : MoneyFormat.precise(minorUnits: abs(balance), currency: currency))
                        .typography(.title3)
                        .foregroundStyle(balance < 0 ? .statusDanger : balance > 0 ? .statusSuccess : .neutralInk)
                } else {
                    ProgressView()
                }
            }
            Spacer(minLength: Spacing.s8)
            Button(action: onSettle) {
                HStack(spacing: Spacing.s4) {
                    Text("Rozliczenia")
                        .typography(.calloutEmphasis)
                    Image(.chevronRight)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                }
                .foregroundStyle(.neutralWhite)
                .padding(.horizontal, Spacing.s16)
                .frame(height: 40)
                .background(.neutralInk, in: .capsule)
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.s16)
        .background(theme.background, in: .rect(cornerRadius: Radius.md))
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty {
            rows.append(current)
        }
        return rows
    }
}
