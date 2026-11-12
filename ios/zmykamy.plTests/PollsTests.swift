import Foundation
import Testing
@testable import zmykamy_pl

@MainActor
struct PollTests {
    @Test func decodesPollsFromTheApi() throws {
        let json = """
        [{"id":"p1","question":"Gdzie na kolację?","status":"resolved","createdBy":"u1",\
        "closesAt":"2027-05-13T18:00:00.000Z","winningOptionId":"o2","planDate":"2027-05-14","myOptionId":"o2",\
        "voterCount":3,"options":[{"id":"o1","name":"Time Out Market","description":null,"voteCount":1,"voterIds":["u3"]},\
        {"id":"o2","name":"Cervejaria Ramiro","description":"owoce morza","voteCount":2,"voterIds":["u1","u2"]}]}]
        """
        let poll = try #require(try APIClient.decoder.decode([Poll].self, from: Data(json.utf8)).first)

        #expect(poll.winningOption?.name == "Cervejaria Ramiro")
        #expect(poll.planDate == LocalDate(year: 2027, month: 5, day: 14))
        #expect(poll.closesAt != nil)
    }

    @Test(arguments: [
        ([:], nil),
        (["a": 0, "b": 0], nil),
        (["a": 2, "b": 2], nil),
        (["a": 3, "b": 1], "a"),
    ] as [([String: Int], String?)])
    func leadsOnlyWithAClearMajority(votes: [String: Int], leader: String?) {
        #expect(Poll.fixture("p", votes: votes).leadingOption?.id == leader)
    }

    @Test func authorsAndOrganizersManagePolls() {
        let poll = Poll.fixture("p", createdBy: "author")

        #expect(Trip.fixture(role: .participant).canManage(poll, userID: "author"))
        #expect(!Trip.fixture(role: .participant).canManage(poll, userID: "someone"))
        #expect(Trip.fixture(role: .organizer).canManage(poll, userID: "someone"))
    }

    @Test func sendsTheClosingTimeAsAnISODate() throws {
        let request = PollRequest(question: "Kiedy?", options: [], closesAt: Date(timeIntervalSince1970: 1_810_000_000))
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]

        #expect(json?["closesAt"] as? String == "2027-05-11T01:46:40Z")
    }
}

@MainActor
struct PollsStoreTests {
    let backend = FakeBackend()
    let trip = Trip.fixture()

    private func store(with polls: [Poll]) async throws -> PollsStore {
        backend.on("GET", "trips/t1/polls", returning: polls)
        let store = PollsStore(api: backend.api(backend.signedIn()))
        try await store.load(trip)
        return store
    }

    @Test func showsNewPollsFirst() async throws {
        let polls = try await store(with: [.fixture("older")])
        backend.on("POST", "trips/t1/polls", returning: Poll.fixture("newer"))

        try await polls.create(PollRequest(question: "newer", options: [], closesAt: nil), in: trip)

        #expect(polls.polls(for: trip)?.map(\.id) == ["newer", "older"])
    }

    @Test func votingShowsTheUpdatedResults() async throws {
        let poll = Poll.fixture("p", votes: ["a": 0, "b": 1])
        let polls = try await store(with: [poll, .fixture("other")])
        backend.on("PUT", "trips/t1/polls/p/vote", returning: Poll.fixture("p", votes: ["a": 1, "b": 1], myOptionId: "a"))

        try await polls.vote(for: poll.options[0], in: poll, of: trip)

        let updated = try #require(polls.polls(for: trip)?.first)
        #expect(updated.myOptionId == "a")
        #expect(updated.voterCount == 2)
        #expect(backend.requests("PUT", "trips/t1/polls/p/vote").first?.json?["optionId"] as? String == "a")
        #expect(polls.polls(for: trip)?.map(\.id) == ["p", "other"])
    }

    @Test func withdrawingAVoteClearsIt() async throws {
        let poll = Poll.fixture("p", votes: ["a": 1], myOptionId: "a")
        let polls = try await store(with: [poll])
        backend.on("DELETE", "trips/t1/polls/p/vote", returning: Poll.fixture("p", votes: ["a": 0]))

        try await polls.withdrawVote(in: poll, of: trip)

        #expect(polls.polls(for: trip)?.first?.myOptionId == nil)
    }

    @Test func deletingAPollRemovesIt() async throws {
        let poll = Poll.fixture("p")
        let polls = try await store(with: [poll, .fixture("other")])
        backend.on("DELETE", "trips/t1/polls/p")

        try await polls.delete(poll, from: trip)

        #expect(polls.polls(for: trip)?.map(\.id) == ["other"])
    }
}
