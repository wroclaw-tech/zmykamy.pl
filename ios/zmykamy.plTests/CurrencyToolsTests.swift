import Foundation
import Testing
@testable import zmykamy_pl

struct CurrencyToolsTests {
    @Test(arguments: [("JPY", "2500", 2500), ("KWD", "2,125", 2125), ("EUR", "25,00", 2500)])
    func parsesAndFormatsTheCurrencyMinorUnits(currency: String, text: String, amount: Int) {
        #expect(MoneyFormat.minorUnits(from: text, currency: currency) == amount)
        #expect(MoneyFormat.minorUnits(from: MoneyFormat.input(minorUnits: amount, currency: currency), currency: currency) == amount)
    }

    @Test func convertsAcrossDifferentMinorUnitScales() {
        #expect(MoneyFormat.convert(2500, from: "EUR", to: "PLN", rate: 4.27) == 10675)
        #expect(MoneyFormat.convert(10000, from: "JPY", to: "PLN", rate: 0.025) == 25000)
        #expect(MoneyFormat.convert(10000, from: "PLN", to: "JPY", rate: 40) == 4000)
        #expect(MoneyFormat.minorUnits(from: "2,5", currency: "JPY") == nil)
        #expect(MoneyFormat.convert(1, from: "PLN", to: "EUR", rate: .infinity) == nil)
        #expect(MoneyFormat.minorUnits(from: "999999999999999999999999999999") == nil)
    }

    @Test func decodesForeignExpenseAndPreservesOriginalValues() throws {
        let data = Data(#"{"id":"e1","title":"Lody","amount":10675,"date":"2027-05-13","icon":"savings","paidBy":{"userId":"u1","name":"Kuba"},"shares":[],"author":null,"original":{"currency":"EUR","amount":2500,"exchangeRate":4.27,"rateSource":"nbp","rateDate":"2027-05-13","rateTable":"A"}}"#.utf8)
        let expense = try APIClient.decoder.decode(Expense.self, from: data)

        #expect(expense.amount == 10675)
        #expect(expense.original?.amount == 2500)
        #expect(expense.original?.currency == "EUR")
        #expect(expense.original?.rateTable == "A")
    }

    @Test func encodesCustomRatesAndExplicitNbpReset() throws {
        var request = ExpenseRequest(title: "Lody", amount: 2500, date: LocalDate(year: 2027, month: 5, day: 13), icon: .savings, paidBy: "u1", participants: ["u1"], currency: "EUR")
        func json() throws -> [String: Any] { try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as! [String: Any] }
        #expect(try json()["exchangeRate"] == nil)
        request.exchangeRate = .some(4.2)
        #expect(try json()["exchangeRate"] as? Double == 4.2)
        #expect(try json()["currency"] as? String == "EUR")
        request.exchangeRate = .some(nil)
        #expect(try json()["exchangeRate"] is NSNull)
    }

    @Test(arguments: [
        (ConversionUnit.kilometers, ConversionUnit.miles, 5.0, 3.10685596),
        (.kilograms, .pounds, 10, 22.0462262),
        (.celsius, .fahrenheit, 24, 75.2),
        (.fahrenheit, .celsius, -40, -40),
        (.kelvin, .celsius, 273.15, 0),
        (.euShoes, .ukShoes, 42, 8),
    ])
    func convertsUnitsAndSwapsBack(from: ConversionUnit, to: ConversionUnit, input: Double, expected: Double) throws {
        let result = try #require(from.convert(input, to: to))
        #expect(abs(result - expected) < 0.00001)
        #expect(abs(try #require(to.convert(result, to: from)) - input) < 0.00001)
    }

    @Test func rejectsImpossibleOrIncompatibleUnits() {
        #expect(ConversionUnit.celsius.convert(-274, to: .kelvin) == nil)
        #expect(ConversionUnit.kilograms.convert(-1, to: .pounds) == nil)
        #expect(ConversionUnit.meters.convert(1, to: .kilograms) == nil)
        #expect(ConversionUnit.meters.convert(.nan, to: .feet) == nil)
    }
}

@MainActor
@Suite(.offlineCache)
struct ExchangeRatesStoreTests {
    let backend = FakeBackend()
    let trip = Trip.fixture()
    let day = LocalDate(year: 2027, month: 5, day: 13)
    private let rateJSON = #"{"from":"EUR","to":"PLN","rate":4.27,"effectiveDate":"2027-05-12","table":"A"}"#

    private func store() -> ExchangeRatesStore { ExchangeRatesStore(api: backend.api(backend.signedIn())) }

    @Test func loadsAQuoteAndReusesItAfterRelaunchOffline() async throws {
        backend.on("GET", "trips/t1/exchange-rate", json: rateJSON)
        let live = try await store().quote(from: "EUR", to: "PLN", on: day, in: trip)
        #expect(live.value.rate == 4.27)
        #expect(live.value.table == "A")
        #expect(!live.isOffline)
        let request = try #require(backend.requests("GET", "trips/t1/exchange-rate").first)
        #expect(request.query["currency"] == "EUR")
        #expect(request.query["date"] == "2027-05-13")

        backend.goOffline()
        let cached = try await store().quote(from: "EUR", to: "PLN", on: day, in: trip)
        #expect(cached.value == live.value)
        #expect(cached.isOffline)
    }

    @Test func neverReusesAnotherExpenseDaysRate() async throws {
        backend.on("GET", "trips/t1/exchange-rate", json: rateJSON)
        _ = try await store().quote(from: "EUR", to: "PLN", on: day, in: trip)
        backend.goOffline()

        await #expect(throws: APIError.network) {
            _ = try await store().quote(from: "EUR", to: "PLN", on: LocalDate(year: 2027, month: 5, day: 14), in: trip)
        }
    }

    @Test func invertsTheRateWhenTheTripCurrencyIsTheSource() async throws {
        backend.on("GET", "trips/t1/exchange-rate", json: rateJSON)
        let result = try await store().quote(from: "PLN", to: "EUR", on: day, in: trip)
        #expect(abs(result.value.rate - 1 / 4.27) < 0.000001)
        #expect(result.value.table == "A")
    }

    @Test func doesNotHideAccessErrorsBehindCachedRates() async throws {
        backend.on("GET", "trips/t1/exchange-rate", json: rateJSON)
        _ = try await store().quote(from: "EUR", to: "PLN", on: day, in: trip)
        backend.on("GET", "trips/t1/exchange-rate", status: 403)

        await #expect(throws: APIError.forbidden) {
            _ = try await store().quote(from: "EUR", to: "PLN", on: day, in: trip)
        }
    }
}

extension ExchangeRatesStoreTests {
    @Test func calculatorCanUseAnOlderQuoteButExpensesRequireTheirExactDay() async throws {
        backend.on("GET", "trips/t1/exchange-rate", json: rateJSON)
        _ = try await store().quote(from: "EUR", to: "PLN", on: day, in: trip)
        backend.goOffline()
        let tomorrow = LocalDate(year: 2027, month: 5, day: 14)

        let result = try await store().quote(from: "EUR", to: "PLN", on: tomorrow, in: trip, allowStale: true)
        #expect(result.isOffline)
        #expect(result.value.effectiveDate == LocalDate(year: 2027, month: 5, day: 12))
        await #expect(throws: APIError.network) {
            _ = try await store().quote(from: "EUR", to: "PLN", on: tomorrow, in: trip)
        }
    }

    @Test func crossesCachedCurrenciesWithoutLosingTableAttribution() async throws {
        backend.on("GET", "trips/t1/exchange-rate", json: rateJSON)
        _ = try await store().quote(from: "EUR", to: "PLN", on: day, in: trip)
        backend.on("GET", "trips/t1/exchange-rate", json: #"{"from":"USD","to":"PLN","rate":4,"effectiveDate":"2027-05-10","table":"B"}"#)
        _ = try await store().quote(from: "USD", to: "PLN", on: day, in: trip)
        backend.goOffline()

        let result = try await store().quote(from: "EUR", to: "USD", on: day, in: trip)
        #expect(abs(result.value.rate - 4.27 / 4) < 0.000001)
        #expect(result.value.table == "A/B")
        #expect(result.value.effectiveDate == LocalDate(year: 2027, month: 5, day: 10))
        #expect(result.isOffline)
    }
}

@MainActor
struct ForeignExpensesStoreTests {
    let backend = FakeBackend()
    let trip = Trip.fixture()
    private let originalJSON = #"{"id":"e1","title":"Lody","amount":10675,"date":"2027-05-13","icon":"savings","paidBy":{"userId":"u1","name":"Kuba"},"shares":[],"author":null,"original":{"currency":"EUR","amount":2500,"exchangeRate":4.27,"rateSource":"nbp","rateDate":"2027-05-13","rateTable":"A"}}"#

    @Test func editingSendsEnteredCurrencyAndUpdatesTheStoredOriginal() async throws {
        let original = try APIClient.decoder.decode(Expense.self, from: Data(originalJSON.utf8))
        backend.on("GET", "trips/t1/expenses", returning: ExpenseList(expenses: [original]))
        backend.on("GET", "trips/t1/settlement", json: #"{"balances":[],"transfers":[],"payments":[],"naiveTransferCount":0}"#)
        backend.on("GET", "trips/t1", returning: trip)
        let auth = backend.signedIn()
        let store = ExpensesStore(api: backend.api(auth), trips: TripsStore(auth: auth, client: backend.apiClient))
        try await store.load(trip)
        backend.on("PATCH", "trips/t1/expenses/e1", json: originalJSON.replacingOccurrences(of: "10675", with: "21350").replacingOccurrences(of: "2500", with: "5000"))
        let request = ExpenseRequest(title: "Lody", amount: 5000, date: original.date, icon: .savings, paidBy: "u1", participants: ["u1"], currency: "EUR", exchangeRate: .some(nil))

        try await store.update(original, with: request, in: trip)

        let sent = try #require(backend.requests("PATCH", "trips/t1/expenses/e1").first?.json)
        #expect(sent["amount"] as? Int == 5000)
        #expect(sent["currency"] as? String == "EUR")
        #expect(sent["exchangeRate"] is NSNull)
        #expect(store.expenses(for: trip)?.first?.original?.amount == 5000)
        #expect(store.expenses(for: trip)?.first?.amount == 21350)
    }
}
