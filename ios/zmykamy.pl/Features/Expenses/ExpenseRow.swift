import SwiftUI

struct ExpenseRow: View {
    let expense: Expense
    let members: [TripMember]
    let currency: String
    let userID: String
    @Environment(\.theme) private var theme

    private var payerName: String {
        expense.paidBy.userId == userID ? "Ty" : expense.paidBy.name
    }

    private var splitText: String {
        expense.isShared(byAllOf: members) ? "na wszystkich" : "na \(expense.shares.count) os."
    }

    private var myShare: Int {
        expense.share(of: userID)
    }

    var body: some View {
        HStack(spacing: Spacing.s12) {
            Image(expense.icon.resource)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(.neutralInk)
                .frame(width: 44, height: 44)
                .background(theme.background, in: .rect(cornerRadius: Radius.sm))
                .overlay(alignment: .bottomTrailing) {
                    PersonAvatar(
                        userID: expense.paidBy.userId,
                        name: expense.paidBy.name,
                        isViewer: expense.paidBy.userId == userID,
                        size: 18,
                        borderColor: .neutralWhite
                    )
                    .offset(x: 4, y: 4)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.title)
                    .typography(.bodyEmphasis)
                    .foregroundStyle(.neutralInk)
                    .lineLimit(1)
                Text("Płatnik: \(payerName) · \(splitText)")
                    .typography(.captionRegular)
                    .foregroundStyle(.neutralGray)
                    .lineLimit(1)
            }
            Spacer(minLength: Spacing.s8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(MoneyFormat.string(minorUnits: expense.amount, currency: currency))
                    .typography(.bodyEmphasis)
                    .foregroundStyle(.neutralInk)
                if let original = expense.original {
                    Text(MoneyFormat.string(minorUnits: original.amount, currency: original.currency))
                        .typography(.captionRegular).foregroundStyle(.neutralGray)
                }
                Text(myShare > 0 ? "Twój udział \(MoneyFormat.string(minorUnits: myShare, currency: currency))" : "Bez Ciebie")
                    .typography(.captionEmphasis)
                    .foregroundStyle(myShare > 0 && expense.paidBy.userId != userID ? .statusDanger : .neutralGray)
            }
        }
        .padding(.horizontal, Spacing.s14)
        .padding(.vertical, Spacing.s12)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
