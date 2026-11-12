import Foundation
import Testing
@testable import zmykamy_pl

@MainActor
@Suite(.offlineCache)
struct TripsStoreTests {
    let backend = FakeBackend()

    private func store() -> TripsStore {
        TripsStore(auth: backend.signedIn(), client: backend.apiClient)
    }

    @Test func showsLastSeenTripsWhenOffline() async throws {
        backend.on("GET", "trips", returning: [Trip.fixture(id: "lisbon"), Trip.fixture(id: "zakopane")])
        try await store().load()

        backend.offline("GET", "trips")
        let relaunched = store()
        try await relaunched.load()

        #expect(relaunched.trips.map(\.id) == ["lisbon", "zakopane"])
        #expect(relaunched.isOffline)
        #expect(relaunched.hasLoaded)
    }

    @Test func leavesOfflineModeOnceTheServerIsBack() async throws {
        backend.on("GET", "trips", returning: [Trip.fixture()])
        let trips = store()
        try await trips.load()
        backend.offline("GET", "trips")
        try await trips.load()

        backend.on("GET", "trips", returning: [Trip.fixture()])
        try await trips.load()

        #expect(!trips.isOffline)
    }

    @Test func failsWhenOfflineOnFirstLaunch() async {
        backend.goOffline()
        let trips = store()

        await #expect(throws: APIError.network) {
            try await trips.load()
        }
        #expect(trips.trips.isEmpty)
    }

    @Test func joiningATripAddsItToTheList() async throws {
        backend.on("GET", "trips", returning: [Trip.fixture(id: "lisbon")])
        backend.on("POST", "invites/LIZ-6K2PX9QM/join", returning: Trip.fixture(id: "zakopane"))
        let trips = store()
        try await trips.load()

        let joined = try await trips.join(inviteCode: "LIZ-6K2PX9QM")

        #expect(joined.id == "zakopane")
        #expect(trips.trips.map(\.id) == ["lisbon", "zakopane"])
    }

    @Test func rejoiningATripDoesNotDuplicateIt() async throws {
        backend.on("GET", "trips", returning: [Trip.fixture(id: "lisbon", name: "Lizbona")])
        backend.on("POST", "invites/LIZ-6K2PX9QM/join", returning: Trip.fixture(id: "lisbon", name: "Lizbona 2027"))
        let trips = store()
        try await trips.load()

        _ = try await trips.join(inviteCode: "LIZ-6K2PX9QM")

        #expect(trips.trips.map(\.name) == ["Lizbona 2027"])
    }

    @Test func previewsAnInviteWithoutBeingSignedIn() async throws {
        backend.on("GET", "invites/LIZ-6K2PX9QM", json: """
        {"tripId":"t1","name":"Lizbona","destination":{"name":"Lizbona","country":"Portugalia"},\
        "startDate":"2027-05-12","endDate":"2027-05-18","organizerName":"Ola","memberCount":4}
        """)
        let trips = TripsStore(auth: backend.authStore(), client: backend.apiClient)

        let preview = try await trips.preview(inviteCode: "LIZ-6K2PX9QM")

        #expect(preview.organizerName == "Ola")
        #expect(preview.memberCount == 4)
        #expect(backend.requests.first?.header("Authorization") == nil)
    }

    @Test func leavingOrDeletingATripRemovesIt() async throws {
        backend.on("GET", "trips", returning: [Trip.fixture(id: "a"), Trip.fixture(id: "b"), Trip.fixture(id: "c")])
        backend.on("DELETE", "trips/a/members/me")
        backend.on("DELETE", "trips/b")
        let trips = store()
        try await trips.load()

        try await trips.leave(Trip.fixture(id: "a"))
        try await trips.delete(Trip.fixture(id: "b"))

        #expect(trips.trips.map(\.id) == ["c"])
    }

    @Test func keepsTheTripWhenTheServerRefusesToDeleteIt() async throws {
        backend.on("GET", "trips", returning: [Trip.fixture(id: "a")])
        backend.on("DELETE", "trips/a", status: 403)
        let trips = store()
        try await trips.load()

        await #expect(throws: APIError.forbidden) {
            try await trips.delete(Trip.fixture(id: "a"))
        }
        #expect(trips.trips.map(\.id) == ["a"])
    }

    @Test func loadsTripProgress() async throws {
        backend.on("GET", "trips/t1", json: """
        {"progress":{"packing":{"mine":{"packedCount":3,"totalCount":10},"shared":{"packedCount":0,"totalCount":2}},\
        "tasks":{"doneCount":1,"totalCount":4},"polls":{"openCount":2,"awaitingMyVoteCount":1}}}
        """)
        let trips = store()

        try await trips.loadProgress(of: .fixture())

        #expect(trips.progress["t1"]?.packing.mine == TripProgress.Count(packedCount: 3, totalCount: 10))
        #expect(trips.progress["t1"]?.polls.awaitingMyVoteCount == 1)
    }
}
