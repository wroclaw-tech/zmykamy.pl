import Foundation

nonisolated enum PollStatus: String, Codable, Sendable {
    case open
    case closed
    case resolved
}

nonisolated struct PollOption: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let description: String?
    let voteCount: Int
    let voterIds: [String]
}

nonisolated struct Poll: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let question: String
    let status: PollStatus
    let createdBy: String
    let closesAt: Date?
    let winningOptionId: String?
    let planDate: LocalDate?
    let myOptionId: String?
    let voterCount: Int
    let options: [PollOption]

    var winningOption: PollOption? {
        options.first { $0.id == winningOptionId }
    }

    var leadingOption: PollOption? {
        let top = options.map(\.voteCount).max() ?? 0
        let leaders = options.filter { $0.voteCount == top }
        return top > 0 && leaders.count == 1 ? leaders.first : nil
    }
}

nonisolated struct PollOptionRequest: Encodable, Sendable {
    let name: String
    let description: String?
}

nonisolated struct PollRequest: Encodable, Sendable {
    let question: String
    let options: [PollOptionRequest]
    let closesAt: String?

    init(question: String, options: [PollOptionRequest], closesAt: Date?) {
        self.question = question
        self.options = options
        self.closesAt = closesAt?.ISO8601Format()
    }
}

nonisolated struct PollVoteRequest: Encodable, Sendable {
    let optionId: String
}

nonisolated struct PollResolveRequest: Encodable, Sendable {
    let optionId: String
    let planDate: LocalDate?
}

extension Trip {
    func canManage(_ poll: Poll, userID: String) -> Bool {
        isOrganizer || poll.createdBy == userID
    }
}
