import Observation

@Observable
final class PollsStore {
    private(set) var polls: [Trip.ID: [Poll]] = [:]

    private let api: AuthorizedAPI

    init(api: AuthorizedAPI, polls: [Trip.ID: [Poll]] = [:]) {
        self.api = api
        self.polls = polls
    }

    func polls(for trip: Trip) -> [Poll]? {
        polls[trip.id]
    }

    func load(_ trip: Trip) async throws(APIError) {
        polls[trip.id] = try await api.call { (client, token) throws(APIError) in
            try await client.send("GET", "trips/\(trip.id)/polls", token: token)
        }
    }

    func create(_ request: PollRequest, in trip: Trip) async throws(APIError) {
        let created: Poll = try await api.call { (client, token) throws(APIError) in
            try await client.send("POST", "trips/\(trip.id)/polls", body: request, token: token)
        }
        polls[trip.id, default: []].insert(created, at: 0)
    }

    func vote(for option: PollOption, in poll: Poll, of trip: Trip) async throws(APIError) {
        let updated: Poll = try await api.call { (client, token) throws(APIError) in
            try await client.send("PUT", "trips/\(trip.id)/polls/\(poll.id)/vote", body: PollVoteRequest(optionId: option.id), token: token)
        }
        replace(updated, in: trip)
    }

    func withdrawVote(in poll: Poll, of trip: Trip) async throws(APIError) {
        let updated: Poll = try await api.call { (client, token) throws(APIError) in
            try await client.send("DELETE", "trips/\(trip.id)/polls/\(poll.id)/vote", token: token)
        }
        replace(updated, in: trip)
    }

    func resolve(_ poll: Poll, with request: PollResolveRequest, in trip: Trip) async throws(APIError) {
        let updated: Poll = try await api.call { (client, token) throws(APIError) in
            try await client.send("POST", "trips/\(trip.id)/polls/\(poll.id)/resolve", body: request, token: token)
        }
        replace(updated, in: trip)
    }

    func delete(_ poll: Poll, from trip: Trip) async throws(APIError) {
        try await api.call { (client, token) throws(APIError) in
            try await client.send("DELETE", "trips/\(trip.id)/polls/\(poll.id)", token: token)
        }
        polls[trip.id]?.removeAll { $0.id == poll.id }
    }

    private func replace(_ poll: Poll, in trip: Trip) {
        guard let index = polls[trip.id]?.firstIndex(where: { $0.id == poll.id }) else { return }
        polls[trip.id]?[index] = poll
    }
}
