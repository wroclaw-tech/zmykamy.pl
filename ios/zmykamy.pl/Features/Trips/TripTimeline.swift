import Foundation

nonisolated enum TripPhase: Equatable {
    case upcoming(daysLeft: Int)
    case ongoing(day: Int, of: Int)
    case past
}

nonisolated extension Trip {
    func phase(on today: LocalDate, calendar: Calendar = .current) -> TripPhase {
        if today < startDate {
            return .upcoming(daysLeft: today.days(until: startDate, calendar: calendar))
        }
        if today > endDate {
            return .past
        }
        return .ongoing(
            day: startDate.days(until: today, calendar: calendar) + 1,
            of: startDate.days(until: endDate, calendar: calendar) + 1
        )
    }
}

/// Splits trips into the list sections: the hero trip, upcoming ones and finished ones.
nonisolated struct TripSections: Equatable {
    let featured: Trip?
    let planned: [Trip]
    let past: [Trip]

    init(trips: [Trip], today: LocalDate) {
        let ongoing = trips
            .filter { $0.startDate <= today && today <= $0.endDate }
            .sorted { $0.endDate < $1.endDate }
        let upcoming = trips
            .filter { today < $0.startDate }
            .sorted { $0.startDate < $1.startDate }
        let featured = ongoing.first ?? upcoming.first

        self.featured = featured
        self.planned = (ongoing + upcoming)
            .filter { $0.id != featured?.id }
            .sorted { $0.startDate < $1.startDate }
        self.past = trips
            .filter { $0.endDate < today }
            .sorted { $0.endDate > $1.endDate }
    }

    var isEmpty: Bool {
        featured == nil && past.isEmpty
    }
}

nonisolated enum PolishPlural {
    /// Picks the Polish noun form for a count, e.g. 1 noc, 2 noce, 5 nocy, 22 noce.
    static func form(_ count: Int, one: String, few: String, many: String) -> String {
        if count == 1 { return one }
        let lastDigit = count % 10
        let lastTwoDigits = count % 100
        if (2...4).contains(lastDigit) && !(12...14).contains(lastTwoDigits) { return few }
        return many
    }

    static func days(_ count: Int) -> String {
        "\(count) \(count == 1 ? "dzień" : "dni")"
    }

    static func nights(_ count: Int) -> String {
        "\(count) \(form(count, one: "noc", few: "noce", many: "nocy"))"
    }

    static func people(_ count: Int) -> String {
        "\(count) \(form(count, one: "osoba", few: "osoby", many: "osób"))"
    }
}

nonisolated enum TripDateFormat {
    private static let locale = Locale(identifier: "pl_PL")

    /// "12–18 maja 2027", or "29 grudnia 2026 – 2 stycznia 2027" across years.
    static func range(_ start: LocalDate, _ end: LocalDate, calendar: Calendar = .current) -> String {
        interval(start, end, calendar: calendar, style: .interval.day().month(.wide).year())
    }

    /// "29 gru – 2 sty", or "8–15 sie 2026" with the year, for compact rows.
    static func shortRange(_ start: LocalDate, _ end: LocalDate, includesYear: Bool = false) -> String {
        let months = ["sty", "lut", "mar", "kwi", "maj", "cze", "lip", "sie", "wrz", "paź", "lis", "gru"]
        let endText = "\(end.day) \(months[end.month - 1])"
        let dates = (start.year, start.month) == (end.year, end.month)
            ? "\(start.day)–\(endText)"
            : "\(start.day) \(months[start.month - 1]) – \(endText)"
        return includesYear ? "\(dates) \(end.year)" : dates
    }

    /// "12–18 maja · 6 nocy", or "12 maja · 1 dzień" for a single day.
    static func summary(_ start: LocalDate, _ end: LocalDate, calendar: Calendar = .current) -> String {
        let nights = start.days(until: end, calendar: calendar)
        let dates = interval(start, end, calendar: calendar, style: .interval.day().month(.wide))
        return "\(dates) · \(nights == 0 ? PolishPlural.days(1) : PolishPlural.nights(nights))"
    }

    /// "w środę", "we wtorek".
    static func weekdayPhrase(_ date: LocalDate, calendar: Calendar = .current) -> String {
        let phrases = ["w niedzielę", "w poniedziałek", "we wtorek", "w środę", "w czwartek", "w piątek", "w sobotę"]
        return phrases[calendar.component(.weekday, from: date.date(in: calendar)) - 1]
    }

    /// "12 maja".
    static func dayMonth(_ date: LocalDate, calendar: Calendar = .current) -> String {
        date.date(in: calendar).formatted(.dateTime.day().month(.wide).locale(locale))
    }

    private static func interval(
        _ start: LocalDate,
        _ end: LocalDate,
        calendar: Calendar,
        style: Date.IntervalFormatStyle
    ) -> String {
        var style = style
        style.locale = locale
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        let (lower, upper) = (start.date(in: calendar), end.date(in: calendar))
        return (min(lower, upper)..<max(lower, upper)).formatted(style)
    }
}
