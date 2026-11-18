import Foundation

nonisolated enum EmailInviteStatus: String, Codable, Sendable {
    case sent
    case joined
}

nonisolated struct EmailInvite: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let email: String
    let status: EmailInviteStatus
    let sentAt: Date
    let joinedAt: Date?
}

nonisolated struct EmailInviteRequest: Encodable, Sendable {
    let emails: [String]
}

nonisolated struct EmailInviteResult: Decodable, Equatable, Sendable {
    let invites: [EmailInvite]
    let alreadyMembers: [String]
    let alreadyInvited: [String]
    let failed: [String]

    var summary: String {
        var lines: [String] = []
        if !invites.isEmpty {
            let count = invites.count
            lines.append("Wysłano \(count) \(PolishPlural.form(count, one: "zaproszenie", few: "zaproszenia", many: "zaproszeń")).")
        }
        if !alreadyMembers.isEmpty {
            lines.append("Już w ekipie: \(alreadyMembers.joined(separator: ", ")).")
        }
        if !alreadyInvited.isEmpty {
            lines.append("Już zaproszeni: \(alreadyInvited.joined(separator: ", ")).")
        }
        if !failed.isEmpty {
            lines.append("Nie udało się wysłać: \(failed.joined(separator: ", ")).")
        }
        return lines.joined(separator: "\n")
    }
}

nonisolated struct PendingEmailInvite: Decodable, Equatable, Identifiable, Sendable {
    struct TripSummary: Decodable, Equatable, Sendable {
        let id: String
        let name: String
        let destination: InvitePreview.Destination?
        let startDate: LocalDate
        let endDate: LocalDate
    }

    let id: String
    let code: String
    let trip: TripSummary
    let inviterName: String?
    let sentAt: Date
}

nonisolated enum EmailAddresses {
    static let maxPerRequest = 10

    struct Parsed: Equatable {
        let valid: [String]
        let invalid: [String]
    }

    static func parse(_ text: String) -> Parsed {
        var valid: [String] = []
        var invalid: [String] = []
        for part in text.split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == ";" }) {
            let email = part.lowercased()
            if email.wholeMatch(of: /[^@\s]+@[^@\s]+\.[^@\s]+/) == nil {
                if !invalid.contains(email) { invalid.append(email) }
            } else if !valid.contains(email) {
                valid.append(email)
            }
        }
        return Parsed(valid: valid, invalid: invalid)
    }
}
