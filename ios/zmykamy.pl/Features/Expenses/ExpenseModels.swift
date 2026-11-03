import Foundation

nonisolated struct ExpensePerson: Codable, Hashable, Sendable {
    let userId: String
    let name: String
}

nonisolated struct ExpenseShare: Codable, Equatable, Sendable {
    let userId: String
    let name: String
    let amount: Int
}

nonisolated struct Expense: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let amount: Int
    let date: LocalDate
    let icon: PlanIcon
    let paidBy: ExpensePerson
    let shares: [ExpenseShare]
    let author: ExpensePerson?

    func share(of userID: String) -> Int {
        shares.first { $0.userId == userID }?.amount ?? 0
    }

    func isShared(byAllOf members: [TripMember]) -> Bool {
        let participants = Set(shares.map(\.userId))
        return members.allSatisfy { participants.contains($0.userId) }
    }
}

nonisolated struct ExpenseList: Codable, Equatable, Sendable {
    var expenses: [Expense]
}

nonisolated struct ExpenseRequest: Encodable, Sendable {
    let title: String
    let amount: Int
    let date: LocalDate
    let icon: PlanIcon
    let paidBy: String
    let participants: [String]
}

nonisolated struct PaymentDetails: Codable, Equatable, Sendable {
    let blikPhone: String?
    let iban: String?
}

nonisolated struct SettlementBalance: Codable, Equatable, Sendable {
    let userId: String
    let name: String
    let balance: Int
}

nonisolated struct SettlementTransfer: Codable, Equatable, Identifiable, Sendable {
    let from: ExpensePerson
    let to: ExpensePerson
    let amount: Int
    let paymentDetails: PaymentDetails?

    var id: String { "\(from.userId)>\(to.userId)" }
}

nonisolated struct SettlementPayment: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let from: ExpensePerson
    let to: ExpensePerson
    let amount: Int
}

nonisolated struct Settlement: Codable, Equatable, Sendable {
    let balances: [SettlementBalance]
    let transfers: [SettlementTransfer]
    let payments: [SettlementPayment]
    let naiveTransferCount: Int

    var transferCount: Int {
        transfers.count + payments.count
    }

    func balance(of userID: String) -> Int {
        balances.first { $0.userId == userID }?.balance ?? 0
    }

    func transfers(from userID: String) -> [SettlementTransfer] {
        transfers.filter { $0.from.userId == userID }
    }

    func transfers(to userID: String) -> [SettlementTransfer] {
        transfers.filter { $0.to.userId == userID }
    }
}

nonisolated struct PaymentRequest: Encodable, Sendable {
    let fromUserId: String
    let toUserId: String
    let amount: Int
}

nonisolated enum ExpenseSplit {
    static func evenly(_ amount: Int, between userIDs: [String]) -> [String: Int] {
        let sorted = Array(Set(userIDs)).sorted()
        guard !sorted.isEmpty else { return [:] }
        let base = amount / sorted.count
        let remainder = amount - base * sorted.count
        return Dictionary(uniqueKeysWithValues: sorted.enumerated().map { index, userID in
            (userID, base + (index < remainder ? 1 : 0))
        })
    }
}

nonisolated struct ExpenseDay: Identifiable, Equatable, Sendable {
    let date: LocalDate
    let expenses: [Expense]

    var id: LocalDate { date }
    var total: Int { expenses.reduce(0) { $0 + $1.amount } }
}

nonisolated struct ExpenseSummary: Equatable, Sendable {
    struct Payer: Equatable, Identifiable, Sendable {
        let userId: String
        let name: String
        let amount: Int

        var id: String { userId }
    }

    let total: Int
    let myShare: Int
    let payers: [Payer]
    let days: [ExpenseDay]

    init(expenses: [Expense], members: [TripMember], userID: String) {
        total = expenses.reduce(0) { $0 + $1.amount }
        myShare = expenses.reduce(0) { $0 + $1.share(of: userID) }

        var paid: [String: Int] = [:]
        var names: [String: String] = [:]
        for expense in expenses {
            paid[expense.paidBy.userId, default: 0] += expense.amount
            names[expense.paidBy.userId] = expense.paidBy.name
        }
        let memberOrder = Dictionary(uniqueKeysWithValues: members.enumerated().map { ($1.userId, $0) })
        payers = paid
            .map { Payer(userId: $0.key, name: names[$0.key] ?? "", amount: $0.value) }
            .sorted { lhs, rhs in
                if (lhs.userId == userID) != (rhs.userId == userID) { return lhs.userId == userID }
                return (memberOrder[lhs.userId] ?? .max, lhs.name) < (memberOrder[rhs.userId] ?? .max, rhs.name)
            }

        days = Dictionary(grouping: expenses, by: \.date)
            .map { ExpenseDay(date: $0.key, expenses: $0.value) }
            .sorted { $0.date > $1.date }
    }
}

nonisolated enum MoneyFormat {
    private static let locale = Locale(identifier: "pl_PL")

    static func string(minorUnits: Int, currency: String) -> String {
        let value = Decimal(minorUnits) / 100
        let style = Decimal.FormatStyle.Currency(code: currency).locale(locale)
        return minorUnits % 100 == 0 ? value.formatted(style.precision(.fractionLength(0))) : value.formatted(style)
    }

    static func symbol(currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currency
        return formatter.currencySymbol ?? currency
    }

    static func precise(minorUnits: Int, currency: String) -> String {
        (Decimal(minorUnits) / 100).formatted(.currency(code: currency).locale(locale))
    }

    static func minorUnits(from text: String) -> Int? {
        let cleaned = text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let value = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")), value > 0 else {
            return nil
        }
        let parts = cleaned.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2, (parts.count < 2 || parts[1].count <= 2) else { return nil }
        var scaled = value * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    static func input(minorUnits: Int) -> String {
        minorUnits % 100 == 0 ? "\(minorUnits / 100)" : String(format: "%d,%02d", minorUnits / 100, minorUnits % 100)
    }
}
