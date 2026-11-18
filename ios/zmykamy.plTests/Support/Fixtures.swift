import Foundation
@testable import zmykamy_pl

// Small builders for API models. Defaults are deliberately boring; pass only what the test is about.

extension AuthUser {
    static func fixture(id: String = "u1", name: String = "Kuba", email: String = "kuba@zmykamy.pl") -> AuthUser {
        AuthUser(id: id, name: name, email: email, image: nil, themePalette: nil, termsVersion: nil, termsAcceptedAt: nil)
    }
}

extension Trip {
    static func fixture(
        id: String = "t1",
        name: String = "Lizbona",
        from start: LocalDate = LocalDate(year: 2027, month: 5, day: 12),
        to end: LocalDate = LocalDate(year: 2027, month: 5, day: 18),
        role: TripRole = .organizer
    ) -> Trip {
        Trip(id: id, name: name, destination: nil, startDate: start, endDate: end, currency: "PLN", coverUrl: nil, myRole: role, members: [])
    }
}

extension TripTask {
    static func fixture(_ id: String, due: LocalDate? = nil, isDone: Bool = false) -> TripTask {
        TripTask(id: id, title: id, assigneeId: nil, dueDate: due, isDone: isDone, completedAt: nil, createdBy: "u1")
    }
}

extension PackingItem {
    static func fixture(_ id: String, scope: PackingScope = .personal, isPacked: Bool = false) -> PackingItem {
        PackingItem(id: id, scope: scope, name: id, assigneeId: nil, isPacked: isPacked, createdBy: "u1")
    }
}

extension PlanPoint {
    static func fixture(
        _ id: String,
        on date: LocalDate,
        at time: PlanTime,
        icon: PlanIcon = .park,
        coordinate: PlanCoordinate? = nil
    ) -> PlanPoint {
        PlanPoint(
            id: id,
            date: date,
            time: time,
            title: id,
            description: nil,
            place: nil,
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude,
            icon: icon,
            author: nil
        )
    }
}

extension TripNote {
    static func fixture(_ id: String, pinned: Bool = false, updatedAt: String) -> TripNote {
        TripNote(id: id, title: id, text: "", pinned: pinned, author: nil, updatedAt: updatedAt)
    }
}

extension Poll {
    static func fixture(
        _ id: String,
        createdBy: String = "u1",
        votes: [String: Int] = [:],
        myOptionId: String? = nil
    ) -> Poll {
        Poll(
            id: id,
            question: id,
            status: .open,
            createdBy: createdBy,
            closesAt: nil,
            winningOptionId: nil,
            planDate: nil,
            myOptionId: myOptionId,
            voterCount: votes.values.reduce(0, +),
            options: votes.keys.sorted().map { PollOption(id: $0, name: $0, description: nil, voteCount: votes[$0]!, voterIds: []) }
        )
    }
}
