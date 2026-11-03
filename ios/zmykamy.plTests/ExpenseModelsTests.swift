import Foundation
import Testing
@testable import zmykamy_pl

struct ExpenseModelsTests {
    private func member(_ id: String, _ name: String) -> TripMember {
        TripMember(userId: id, name: name, image: nil, role: .participant, balance: 0)
    }

    private func expense(_ id: String, amount: Int, on date: LocalDate, paidBy payer: String, shares: [String: Int]) -> Expense {
        Expense(
            id: id,
            title: id,
            amount: amount,
            date: date,
            icon: .savings,
            paidBy: ExpensePerson(userId: payer, name: payer.uppercased()),
            shares: shares.map { ExpenseShare(userId: $0.key, name: $0.key.uppercased(), amount: $0.value) },
            author: nil
        )
    }

    @Test func splitsEvenlyLikeTheApi() {
        #expect(ExpenseSplit.evenly(100, between: ["c", "a", "b"]) == ["a": 34, "b": 33, "c": 33])
        #expect(ExpenseSplit.evenly(9600, between: ["a", "b", "c", "d"]).values.allSatisfy { $0 == 2400 })
        #expect(ExpenseSplit.evenly(100, between: []).isEmpty)
    }

    @Test(arguments: [
        ("96", 9600),
        ("12,5", 1250),
        ("1 243,33", 124333),
        ("0,01", 1),
        ("7.99", 799),
    ])
    func parsesTypedAmounts(text: String, minorUnits: Int) {
        #expect(MoneyFormat.minorUnits(from: text) == minorUnits)
    }

    @Test(arguments: ["", "0", "abc", "1,234", "-5", "1,2,3"])
    func rejectsInvalidAmounts(text: String) {
        #expect(MoneyFormat.minorUnits(from: text) == nil)
    }

    @Test func roundTripsAmountInput() {
        #expect(MoneyFormat.input(minorUnits: 9600) == "96")
        #expect(MoneyFormat.input(minorUnits: 1250) == "12,50")
        #expect(MoneyFormat.minorUnits(from: MoneyFormat.input(minorUnits: 209133)) == 209133)
    }

    @Test func summarizesTotalsSharesAndDays() {
        let monday = LocalDate(year: 2027, month: 5, day: 12)
        let tuesday = LocalDate(year: 2027, month: 5, day: 13)
        let members = [member("me", "Kuba"), member("ola", "Ola"), member("zuza", "Zuza")]
        let expenses = [
            expense("kawa", amount: 7200, on: tuesday, paidBy: "zuza", shares: ["me": 2400, "ola": 2400, "zuza": 2400]),
            expense("bilety", amount: 3000, on: monday, paidBy: "me", shares: ["me": 1500, "ola": 1500]),
            expense("lody", amount: 900, on: tuesday, paidBy: "ola", shares: ["ola": 900]),
        ]

        let summary = ExpenseSummary(expenses: expenses, members: members, userID: "me")

        #expect(summary.total == 11100)
        #expect(summary.myShare == 3900)
        #expect(summary.payers.map(\.userId) == ["me", "ola", "zuza"])
        #expect(summary.payers.map(\.amount) == [3000, 900, 7200])
        #expect(summary.days.map(\.date) == [tuesday, monday])
        #expect(summary.days.first?.total == 8100)
        #expect(expenses[0].isShared(byAllOf: members))
        #expect(!expenses[1].isShared(byAllOf: members))
    }

    @Test func decodesSettlementFromTheApi() throws {
        let json = """
        {"balances":[{"userId":"u1","name":"Kuba","balance":4500},{"userId":"u2","name":"Ola","balance":-4500}],\
        "transfers":[{"from":{"userId":"u2","name":"Ola"},"to":{"userId":"u1","name":"Kuba"},"amount":4500,\
        "paymentDetails":{"blikPhone":"+48512345678","iban":null}}],\
        "payments":[{"id":"p1","from":{"userId":"u2","name":"Ola"},"to":{"userId":"u1","name":"Kuba"},\
        "amount":100,"createdAt":"2027-05-13T10:00:00.000Z"}],"naiveTransferCount":3}
        """
        let settlement = try APIClient.decoder.decode(Settlement.self, from: Data(json.utf8))

        #expect(settlement.balance(of: "u2") == -4500)
        #expect(settlement.transfers(from: "u2").first?.paymentDetails?.blikPhone == "+48512345678")
        #expect(settlement.transfers(to: "u2").isEmpty)
        #expect(settlement.transferCount == 2)
    }
}
