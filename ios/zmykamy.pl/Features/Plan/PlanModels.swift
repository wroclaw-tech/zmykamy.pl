import Foundation

/// A wall-clock time without a time zone, sent by the API as `HH:mm`.
nonisolated struct PlanTime: Codable, Hashable, Comparable, Sendable {
    let hour: Int
    let minute: Int

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    init(_ date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        let parts = string.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid time: \(string)")
        }
        self.init(hour: parts[0], minute: parts[1])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }

    /// Minutes since midnight.
    init(minutes: Int) {
        let clamped = min(max(minutes, 0), 24 * 60 - 1)
        self.init(hour: clamped / 60, minute: clamped % 60)
    }

    var text: String {
        String(format: "%02d:%02d", hour, minute)
    }

    var minutes: Int {
        hour * 60 + minute
    }

    /// Today at this time, for editing in a time picker.
    func date(calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
    }

    static func < (lhs: PlanTime, rhs: PlanTime) -> Bool {
        (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
    }
}

nonisolated struct PlanAuthor: Codable, Equatable, Sendable {
    let userId: String
    let name: String
}

nonisolated struct PlanPoint: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let date: LocalDate
    let time: PlanTime
    let title: String
    let description: String?
    let place: String?
    let latitude: Double?
    let longitude: Double?
    let icon: PlanIcon
    let author: PlanAuthor?

    var coordinate: PlanCoordinate? {
        guard let latitude, let longitude else { return nil }
        return PlanCoordinate(latitude: latitude, longitude: longitude)
    }

    var subtitle: String? {
        let parts = [place, description].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

nonisolated struct PlanCoordinate: Equatable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double
}

nonisolated struct TripInfoCard: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let text: String
    let icon: PlanIcon
    let author: PlanAuthor?
}

nonisolated struct TripPlan: Codable, Equatable, Sendable {
    var points: [PlanPoint]
    var info: [TripInfoCard]

    static let empty = TripPlan(points: [], info: [])

    func points(on day: LocalDate) -> [PlanPoint] {
        points.filter { $0.date == day }
    }
}

nonisolated struct PlanPointRequest: Encodable, Sendable {
    let date: LocalDate
    let time: PlanTime
    let title: String
    let description: String?
    let place: String?
    let coordinate: PlanCoordinate?
    let icon: PlanIcon

    private enum CodingKeys: String, CodingKey {
        case date, time, title, description, place, latitude, longitude, icon
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(time, forKey: .time)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(place, forKey: .place)
        try container.encode(coordinate?.latitude, forKey: .latitude)
        try container.encode(coordinate?.longitude, forKey: .longitude)
        try container.encode(icon, forKey: .icon)
    }
}

nonisolated struct TripInfoRequest: Encodable, Sendable {
    let title: String
    let text: String
    let icon: PlanIcon
}

nonisolated extension LocalDate {
    func adding(days: Int, calendar: Calendar = .current) -> LocalDate {
        let start = date(in: calendar)
        return LocalDate(calendar.date(byAdding: .day, value: days, to: start) ?? start, calendar: calendar)
    }
}

nonisolated extension Trip {
    func days(calendar: Calendar = .current) -> [LocalDate] {
        let count = max(startDate.days(until: endDate, calendar: calendar), 0)
        return (0...count).map { startDate.adding(days: $0, calendar: calendar) }
    }

    /// Organizers can change everything; participants only what they added.
    func canEdit(authoredBy author: PlanAuthor?, userID: String) -> Bool {
        isOrganizer || author?.userId == userID
    }
}

nonisolated enum PlanDateFormat {
    private static let locale = Locale(identifier: "pl_PL")
    private static let shortWeekdays = ["Nd", "Pn", "Wt", "Śr", "Cz", "Pt", "So"]

    /// "Śr", "Cz".
    static func shortWeekday(_ date: LocalDate, calendar: Calendar = .current) -> String {
        shortWeekdays[calendar.component(.weekday, from: date.date(in: calendar)) - 1]
    }

    /// "piątek, 14 maja".
    static func weekdayDayMonth(_ date: LocalDate, calendar: Calendar = .current) -> String {
        date.date(in: calendar).formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale))
    }

    /// "DZIEŃ 1 · ŚR, 12 MAJA".
    static func wizardHeading(day: Int, date: LocalDate, calendar: Calendar = .current) -> String {
        "DZIEŃ \(day) · \(shortWeekday(date, calendar: calendar)), \(TripDateFormat.dayMonth(date, calendar: calendar))"
            .uppercased(with: locale)
    }
}
