import Observation

@Observable
final class ExpensesStore {
    private(set) var lists: [Trip.ID: [Expense]] = [:]
    private(set) var settlements: [Trip.ID: Settlement] = [:]

    let rates: ExchangeRatesStore

    private let api: AuthorizedAPI
    private let trips: TripsStore

    init(api: AuthorizedAPI, trips: TripsStore) {
        self.api = api
        self.rates = ExchangeRatesStore(api: api)
        self.trips = trips
    }

    func expenses(for trip: Trip) -> [Expense]? {
        lists[trip.id]
    }

    func settlement(for trip: Trip) -> Settlement? {
        settlements[trip.id]
    }

    func load(_ trip: Trip) async throws(APIError) {
        let list: ExpenseList = try await api.call { (client, token) throws(APIError) in
            try await client.send("GET", "trips/\(trip.id)/expenses", token: token)
        }
        lists[trip.id] = list.expenses
        try await loadSettlement(trip)
    }

    func loadSettlement(_ trip: Trip) async throws(APIError) {
        settlements[trip.id] = try await api.call { (client, token) throws(APIError) in
            try await client.send("GET", "trips/\(trip.id)/settlement", token: token)
        }
    }

    func add(_ request: ExpenseRequest, to trip: Trip) async throws(APIError) {
        let created: Expense = try await api.call { (client, token) throws(APIError) in
            try await client.send("POST", "trips/\(trip.id)/expenses", body: request, token: token)
        }
        change(trip) { $0.append(created) }
        await refreshBalances(of: trip)
    }

    func update(_ expense: Expense, with request: ExpenseRequest, in trip: Trip) async throws(APIError) {
        let updated: Expense = try await api.call { (client, token) throws(APIError) in
            try await client.send("PATCH", "trips/\(trip.id)/expenses/\(expense.id)", body: request, token: token)
        }
        change(trip) { list in
            guard let index = list.firstIndex(where: { $0.id == updated.id }) else { return }
            list[index] = updated
        }
        await refreshBalances(of: trip)
    }

    func delete(_ expense: Expense, from trip: Trip) async throws(APIError) {
        try await api.call { (client, token) throws(APIError) in
            try await client.send("DELETE", "trips/\(trip.id)/expenses/\(expense.id)", token: token)
        }
        change(trip) { $0.removeAll { $0.id == expense.id } }
        await refreshBalances(of: trip)
    }

    func markPaid(_ transfer: SettlementTransfer, in trip: Trip) async throws(APIError) {
        let request = PaymentRequest(fromUserId: transfer.from.userId, toUserId: transfer.to.userId, amount: transfer.amount)
        settlements[trip.id] = try await api.call { (client, token) throws(APIError) in
            try await client.send("POST", "trips/\(trip.id)/settlement/payments", body: request, token: token)
        }
        try? await trips.reload(trip.id)
    }

    func undo(_ payment: SettlementPayment, in trip: Trip) async throws(APIError) {
        settlements[trip.id] = try await api.call { (client, token) throws(APIError) in
            try await client.send("DELETE", "trips/\(trip.id)/settlement/payments/\(payment.id)", token: token)
        }
        try? await trips.reload(trip.id)
    }

    private func refreshBalances(of trip: Trip) async {
        try? await loadSettlement(trip)
        try? await trips.reload(trip.id)
    }

    private func change(_ trip: Trip, _ mutation: (inout [Expense]) -> Void) {
        var list = lists[trip.id] ?? []
        mutation(&list)
        lists[trip.id] = list
    }
}
