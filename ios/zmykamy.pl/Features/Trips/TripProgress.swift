import Foundation

nonisolated struct TripProgress: Decodable, Equatable, Sendable {
    struct Packing: Decodable, Equatable, Sendable {
        let mine: Count
        let shared: Count
    }

    struct Count: Decodable, Equatable, Sendable {
        let packedCount: Int
        let totalCount: Int
    }

    struct Tasks: Decodable, Equatable, Sendable {
        let doneCount: Int
        let totalCount: Int
    }

    struct Polls: Decodable, Equatable, Sendable {
        let openCount: Int
        let awaitingMyVoteCount: Int
    }

    let packing: Packing
    let tasks: Tasks
    let polls: Polls
}

nonisolated struct TripDetailsResponse: Decodable, Sendable {
    let progress: TripProgress
}
