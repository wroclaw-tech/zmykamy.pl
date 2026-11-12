import Foundation
import Testing
@testable import zmykamy_pl

@MainActor
struct TasksStoreTests {
    let backend = FakeBackend()
    let trip = Trip.fixture()

    private func store(with tasks: [TripTask]) async throws -> TasksStore {
        backend.on("GET", "trips/t1/tasks", returning: tasks)
        let store = TasksStore(api: backend.api(backend.signedIn()))
        try await store.load(trip)
        return store
    }

    @Test func listsTasksByDueDateWithUndatedOnesLast() async throws {
        let tasks = try await store(with: [
            .fixture("tickets", due: LocalDate(year: 2027, month: 4, day: 1)),
            .fixture("someday"),
        ])

        backend.on("POST", "trips/t1/tasks", returning: TripTask.fixture("insurance", due: LocalDate(year: 2027, month: 3, day: 1)))
        try await tasks.add(TripTaskRequest(title: "insurance", assigneeId: nil, dueDate: LocalDate(year: 2027, month: 3, day: 1)), to: trip)

        #expect(tasks.tasks(for: trip)?.map(\.id) == ["insurance", "tickets", "someday"])
    }

    @Test func completingATaskUpdatesIt() async throws {
        let task = TripTask.fixture("tickets")
        let tasks = try await store(with: [task])
        backend.on("PATCH", "trips/t1/tasks/tickets", returning: TripTask.fixture("tickets", isDone: true))

        try await tasks.update(task, with: TripTaskUpdate(isDone: true), in: trip)

        #expect(tasks.tasks(for: trip)?.first?.isDone == true)
        #expect(backend.requests("PATCH", "trips/t1/tasks/tickets").first?.json?.keys.sorted() == ["isDone"])
    }

    @Test func clearingADueDateSendsNull() async throws {
        let task = TripTask.fixture("tickets", due: LocalDate(year: 2027, month: 4, day: 1))
        let tasks = try await store(with: [task])
        backend.on("PATCH", "trips/t1/tasks/tickets", returning: TripTask.fixture("tickets"))

        try await tasks.update(task, with: TripTaskUpdate(dueDate: .some(nil)), in: trip)

        #expect(backend.requests("PATCH", "trips/t1/tasks/tickets").first?.json?["dueDate"] is NSNull)
    }

    @Test func keepsTheTaskWhenDeletingFails() async throws {
        let task = TripTask.fixture("tickets")
        let tasks = try await store(with: [task])
        backend.offline("DELETE", "trips/t1/tasks/tickets")

        await #expect(throws: APIError.network) {
            try await tasks.delete(task, from: trip)
        }
        #expect(tasks.tasks(for: trip)?.map(\.id) == ["tickets"])
    }
}

@MainActor
struct PackingStoreTests {
    let backend = FakeBackend()
    let trip = Trip.fixture()

    @Test func separatesPersonalAndSharedLists() async throws {
        backend.on("GET", "trips/t1/packing", returning: [
            PackingItem.fixture("passport"),
            PackingItem.fixture("tent", scope: .shared),
            PackingItem.fixture("charger"),
        ])
        let packing = PackingStore(api: backend.api(backend.signedIn()))

        try await packing.load(trip)

        #expect(packing.items(for: trip, scope: .personal)?.map(\.id) == ["passport", "charger"])
        #expect(packing.items(for: trip, scope: .shared)?.map(\.id) == ["tent"])
    }

    @Test func packingAndRemovingItems() async throws {
        let passport = PackingItem.fixture("passport")
        let charger = PackingItem.fixture("charger")
        backend.on("GET", "trips/t1/packing", returning: [passport, charger])
        backend.on("PATCH", "trips/t1/packing/passport", returning: PackingItem.fixture("passport", isPacked: true))
        backend.on("DELETE", "trips/t1/packing/charger")
        let packing = PackingStore(api: backend.api(backend.signedIn()))
        try await packing.load(trip)

        try await packing.update(passport, with: PackingItemUpdate(isPacked: true), in: trip)
        try await packing.delete(charger, from: trip)

        #expect(packing.items(for: trip, scope: .personal) == [PackingItem.fixture("passport", isPacked: true)])
    }
}
