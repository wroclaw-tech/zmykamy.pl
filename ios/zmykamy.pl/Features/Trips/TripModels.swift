import Foundation

/// A calendar day without time or time zone, sent by the API as `yyyy-MM-dd`.
nonisolated struct LocalDate: Codable, Hashable, Comparable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(_ date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year ?? 0, month: components.month ?? 0, day: components.day ?? 0)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(format: "%04d-%02d-%02d", year, month, day))
    }

    func date(in calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    func days(until other: LocalDate, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: date(in: calendar), to: other.date(in: calendar)).day ?? 0
    }

    static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

nonisolated enum TripRole: String, Codable, Sendable {
    case organizer
    case participant
}

nonisolated struct TripDestination: Codable, Equatable, Sendable {
    let name: String
    let country: String?
    let latitude: Double?
    let longitude: Double?
}

nonisolated struct TripMember: Codable, Equatable, Identifiable, Sendable {
    let userId: String
    let name: String
    let image: String?
    let role: TripRole
    /// Minor units of the trip currency; positive when the member is owed money.
    let balance: Int

    var id: String { userId }
}

nonisolated struct Trip: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let destination: TripDestination?
    let startDate: LocalDate
    let endDate: LocalDate
    let currency: String
    let coverUrl: URL?
    let myRole: TripRole
    let members: [TripMember]

    var isOrganizer: Bool { myRole == .organizer }
}

nonisolated struct TripRequest: Encodable, Sendable {
    let name: String
    let destination: TripDestination?
    let startDate: LocalDate
    let endDate: LocalDate
    let currency: String

    private enum CodingKeys: String, CodingKey {
        case name, destination, startDate, endDate, currency
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(destination, forKey: .destination)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(currency, forKey: .currency)
    }
}

nonisolated struct TripCoverRequest: Encodable, Sendable {
    let coverImageKey: String?

    private enum CodingKeys: String, CodingKey {
        case coverImageKey
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(coverImageKey, forKey: .coverImageKey)
    }
}

nonisolated struct CoverUploadResponse: Decodable, Sendable {
    let uploadUrl: URL
    let key: String
}

nonisolated struct TripInvite: Decodable, Equatable, Sendable {
    let code: String
    let url: URL
}

nonisolated struct InvitePreview: Decodable, Equatable, Sendable {
    struct Destination: Decodable, Equatable, Sendable {
        let name: String
        let country: String?
    }

    let tripId: String
    let name: String
    let destination: Destination?
    let startDate: LocalDate
    let endDate: LocalDate
    let organizerName: String?
    let memberCount: Int
}
