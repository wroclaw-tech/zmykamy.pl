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
    var original: OriginalExpense? = nil

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

nonisolated struct OriginalExpense: Codable, Equatable, Sendable {
    let currency: String
    let amount: Int
    let exchangeRate: Double
    let rateSource: String
    let rateDate: LocalDate?
    let rateTable: String?
}

nonisolated struct ExpenseDraft: Identifiable {
    let id = UUID()
    let amount: Int
    let currency: String
}

nonisolated struct ExpenseRequest: Encodable, Sendable {
    let title: String
    let amount: Int
    let date: LocalDate
    let icon: PlanIcon
    let paidBy: String
    let participants: [String]
    var currency: String? = nil
    // nil omits the field; .some(nil) switches an edited expense back to NBP.
    var exchangeRate: Double?? = nil

    private enum CodingKeys: String, CodingKey {
        case title, amount, date, icon, paidBy, participants, currency, exchangeRate
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encode(amount, forKey: .amount)
        try c.encode(date, forKey: .date)
        try c.encode(icon, forKey: .icon)
        try c.encode(paidBy, forKey: .paidBy)
        try c.encode(participants, forKey: .participants)
        try c.encodeIfPresent(currency, forKey: .currency)
        if let exchangeRate { try c.encode(exchangeRate, forKey: .exchangeRate) }
    }
}

/// Only the fields that changed in an edit, so the backend never reprices an expense that
/// wasn't touched. `exchangeRate` of `.some(nil)` switches back to the NBP rate.
nonisolated struct ExpenseUpdate: Encodable, Equatable, Sendable {
    var title: String?
    var amount: Int?
    var currency: String?
    var exchangeRate: Double??
    var date: LocalDate?
    var icon: PlanIcon?
    var paidBy: String?
    var participants: [String]?

    var isEmpty: Bool { self == ExpenseUpdate() }

    init() {}

    init(from expense: Expense, to request: ExpenseRequest, tripCurrency: String) {
        if request.title != expense.title { title = request.title }
        if request.date != expense.date { date = request.date }
        if request.icon != expense.icon { icon = request.icon }
        if request.paidBy != expense.paidBy.userId { paidBy = request.paidBy }
        if Set(request.participants) != Set(expense.shares.map(\.userId)) { participants = request.participants }

        let enteredCurrency = request.currency ?? tripCurrency
        let storedCurrency = expense.original?.currency ?? tripCurrency
        let changesMoney = enteredCurrency != storedCurrency || request.amount != (expense.original?.amount ?? expense.amount)
        if changesMoney {
            amount = request.amount
            currency = enteredCurrency
        }
        guard enteredCurrency != tripCurrency, let requestedRate = request.exchangeRate else { return }
        let storedRate = expense.original?.rateSource == "custom" ? expense.original?.exchangeRate : nil
        // The backend keeps a custom rate only for the same currency, so resend it when the currency changes
        if requestedRate != storedRate || (requestedRate != nil && enteredCurrency != storedCurrency) {
            exchangeRate = .some(requestedRate)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case title, amount, currency, exchangeRate, date, icon, paidBy, participants
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(amount, forKey: .amount)
        try c.encodeIfPresent(currency, forKey: .currency)
        if let exchangeRate { try c.encode(exchangeRate, forKey: .exchangeRate) }
        try c.encodeIfPresent(date, forKey: .date)
        try c.encodeIfPresent(icon, forKey: .icon)
        try c.encodeIfPresent(paidBy, forKey: .paidBy)
        try c.encodeIfPresent(participants, forKey: .participants)
    }
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

    static func digits(for currency: String) -> Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.maximumFractionDigits
    }

    static func scale(for currency: String) -> Decimal {
        pow(Decimal(10), digits(for: currency))
    }

    static func string(minorUnits: Int, currency: String) -> String {
        let value = Decimal(minorUnits) / scale(for: currency)
        let style = Decimal.FormatStyle.Currency(code: currency).locale(locale)
        return value == Decimal(NSDecimalNumber(decimal: value).intValue)
            ? value.formatted(style.precision(.fractionLength(0))) : value.formatted(style)
    }

    static func symbol(currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currency
        return formatter.currencySymbol ?? currency
    }

    static func precise(minorUnits: Int, currency: String) -> String {
        (Decimal(minorUnits) / scale(for: currency)).formatted(.currency(code: currency).locale(locale))
    }

    static func decimal(from text: String) -> Decimal? {
        let cleaned = text.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, cleaned.allSatisfy({ "0123456789.-".contains($0) }),
              cleaned.filter({ $0 == "." }).count <= 1,
              cleaned.filter({ $0 == "-" }).count <= 1,
              !cleaned.contains("-") || cleaned.hasPrefix("-"),
              let value = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")),
              !value.isNaN else { return nil }
        return value
    }

    static func minorUnits(from text: String, currency: String = "PLN") -> Int? {
        guard let value = decimal(from: text), value > 0 else { return nil }
        let cleaned = text.replacingOccurrences(of: ",", with: ".")
        let parts = cleaned.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2, parts.count < 2 || parts[1].count <= digits(for: currency) else { return nil }
        return roundedMinorUnits(value * scale(for: currency))
    }

    static func roundedMinorUnits(_ value: Decimal) -> Int? {
        guard !value.isNaN else { return nil }
        var source = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 0, .plain)
        guard rounded >= 0, rounded <= Decimal(Int.max) else { return nil }
        return NSDecimalNumber(decimal: rounded).intValue
    }

    /// Largest amount the backend accepts, also after conversion to the trip currency.
    static let maxAmount = 100_000_000
    private static let rateScale: Double = 1_000_000

    /// Rounds a rate to the 6 decimal places the backend keeps.
    static func roundedRate(_ rate: Double) -> Double {
        (rate * rateScale).rounded() / rateScale
    }

    /// Converts minor units of `from` into minor units of `to`, rounding half up. Works on the
    /// rate in millionths with exact decimal arithmetic, the same as the backend.
    static func convert(_ amount: Int, from: String, to: String, rate: Double) -> Int? {
        guard rate.isFinite, rate > 0, rate <= 1_000_000 else { return nil }
        let micros = Decimal(Int((rate * rateScale).rounded()))
        return roundedMinorUnits(Decimal(amount) * micros * scale(for: to) / (scale(for: from) * Decimal(rateScale)))
    }

    static func input(minorUnits: Int, currency: String = "PLN") -> String {
        let value = Decimal(minorUnits) / scale(for: currency)
        let digits = value == Decimal(NSDecimalNumber(decimal: value).intValue) ? 0 : digits(for: currency)
        return value.formatted(.number.locale(locale).grouping(.never).precision(.fractionLength(digits)))
    }
}
