import Foundation
import Testing
@testable import zmykamy_pl

@MainActor
@Suite(.offlineCache)
struct DocumentsStoreTests {
    let backend = FakeBackend()
    let trip = Trip.fixture()

    private static let documentsJSON = """
    {"documents":[{"id":"d1","title":"Mieszkanie","category":"reservation","icon":"bed","kind":"link",\
    "url":"https://example.com/booking","fileUrl":null,"contentType":null,"planPointId":"p1",\
    "author":null,"updatedAt":"2027-05-01T10:00:00.000Z"}]}
    """

    private func store() -> DocumentsStore {
        DocumentsStore(api: backend.api(backend.signedIn()))
    }

    @Test func listsPinnedNotesFirstThenMostRecentlyEdited() async throws {
        backend.on("GET", "trips/t1/documents", json: #"{"documents":[]}"#)
        backend.on("GET", "trips/t1/notes", returning: NoteList(notes: [
            .fixture("old", updatedAt: "2027-05-01T10:00:00.000Z"),
            .fixture("wifi", pinned: true, updatedAt: "2027-04-01T10:00:00.000Z"),
        ]))
        backend.on("POST", "trips/t1/notes", returning: TripNote.fixture("new", updatedAt: "2027-05-02T10:00:00.000Z"))
        let documents = store()
        try await documents.load(trip)

        try await documents.addNote(NoteRequest(title: "new", text: "", pinned: false), to: trip)

        #expect(documents.notes(for: trip)?.map(\.id) == ["wifi", "new", "old"])
    }

    @Test func keepsDocumentsAndNotesAvailableOffline() async throws {
        backend.on("GET", "trips/t1/documents", json: Self.documentsJSON)
        backend.on("GET", "trips/t1/notes", returning: NoteList(notes: [.fixture("wifi", updatedAt: "2027-05-01T10:00:00.000Z")]))
        try await store().load(trip)

        backend.goOffline()
        let relaunched = store()
        try await relaunched.load(trip)

        #expect(relaunched.isOffline(trip))
        #expect(relaunched.documents(for: trip)?.map(\.title) == ["Mieszkanie"])
        #expect(relaunched.notes(for: trip)?.map(\.id) == ["wifi"])
    }

    @Test func showsDocumentsAttachedToAPlanPoint() async throws {
        backend.on("GET", "trips/t1/documents", json: Self.documentsJSON)
        backend.on("GET", "trips/t1/notes", json: #"{"notes":[]}"#)
        let documents = store()
        try await documents.load(trip)

        let day = LocalDate(year: 2027, month: 5, day: 12)
        let attached = documents.documents(attachedTo: .fixture("p1", on: day, at: PlanTime(hour: 9, minute: 0)), in: trip)
        let other = documents.documents(attachedTo: .fixture("p2", on: day, at: PlanTime(hour: 9, minute: 0)), in: trip)

        #expect(attached.map(\.id) == ["d1"])
        #expect(other.isEmpty)
    }
}

@MainActor
struct ExpensesStoreTests {
    let backend = FakeBackend()
    let trip = Trip.fixture()

    private static func settlementJSON(balance: Int) -> String {
        """
        {"balances":[{"userId":"u1","name":"Kuba","balance":\(balance)},{"userId":"u2","name":"Ola","balance":\(-balance)}],\
        "transfers":[],"payments":[],"naiveTransferCount":0}
        """
    }

    @Test func addingAnExpenseRefreshesBalances() async throws {
        let day = LocalDate(year: 2027, month: 5, day: 12)
        let expense = Expense(
            id: "e1", title: "Kolacja", amount: 10000, date: day, icon: .savings,
            paidBy: ExpensePerson(userId: "u1", name: "Kuba"),
            shares: [ExpenseShare(userId: "u1", name: "Kuba", amount: 5000), ExpenseShare(userId: "u2", name: "Ola", amount: 5000)],
            author: nil
        )
        backend.on("GET", "trips/t1/expenses", json: #"{"expenses":[]}"#)
        backend.on("GET", "trips/t1/settlement", json: Self.settlementJSON(balance: 0))
        backend.on("GET", "trips/t1", returning: trip)
        let auth = backend.signedIn()
        let expenses = ExpensesStore(api: backend.api(auth), trips: TripsStore(auth: auth, client: backend.apiClient))
        try await expenses.load(trip)

        backend.on("POST", "trips/t1/expenses", returning: expense)
        backend.on("GET", "trips/t1/settlement", json: Self.settlementJSON(balance: 5000))
        try await expenses.add(
            ExpenseRequest(title: "Kolacja", amount: 10000, date: day, icon: .savings, paidBy: "u1", participants: ["u1", "u2"]),
            to: trip
        )

        #expect(expenses.expenses(for: trip)?.map(\.id) == ["e1"])
        #expect(expenses.settlement(for: trip)?.balance(of: "u1") == 5000)
        #expect(expenses.settlement(for: trip)?.balance(of: "u2") == -5000)
    }
}
