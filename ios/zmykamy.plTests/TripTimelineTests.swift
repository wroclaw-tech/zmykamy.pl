import Foundation
import Testing
@testable import zmykamy_pl

struct TripTimelineTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw")!
        return calendar
    }()

    private func trip(_ id: String, from start: LocalDate, to end: LocalDate) -> Trip {
        Trip(
            id: id,
            name: id,
            destination: nil,
            startDate: start,
            endDate: end,
            currency: "PLN",
            coverUrl: nil,
            myRole: .organizer,
            members: []
        )
    }

    @Test func decodesTripDatesAsCalendarDays() throws {
        let json = """
        {"id":"t1","name":"Lizbona","destination":{"name":"Lizbona","country":"Portugalia","latitude":38.7,"longitude":-9.1},\
        "startDate":"2027-05-12","endDate":"2027-05-18","currency":"EUR","coverUrl":null,"myRole":"organizer",\
        "members":[{"userId":"u1","name":"Kuba","image":null,"role":"organizer","balance":0}]}
        """
        let trip = try APIClient.decoder.decode(Trip.self, from: Data(json.utf8))

        #expect(trip.startDate == LocalDate(year: 2027, month: 5, day: 12))
        #expect(trip.endDate == LocalDate(year: 2027, month: 5, day: 18))
        #expect(trip.isOrganizer)
    }

    @Test func encodesRemovedDestinationAsNull() throws {
        let request = TripRequest(
            name: "Sylwek",
            destination: nil,
            startDate: LocalDate(year: 2026, month: 12, day: 29),
            endDate: LocalDate(year: 2027, month: 1, day: 2),
            currency: "PLN"
        )
        let json = try #require(String(data: JSONEncoder().encode(request), encoding: .utf8))

        #expect(json.contains("\"destination\":null"))
        #expect(json.contains("\"startDate\":\"2026-12-29\""))
    }

    @Test(arguments: [
        (LocalDate(year: 2027, month: 5, day: 1), TripPhase.upcoming(daysLeft: 11)),
        (LocalDate(year: 2027, month: 5, day: 11), .upcoming(daysLeft: 1)),
        (LocalDate(year: 2027, month: 5, day: 12), .ongoing(day: 1, of: 7)),
        (LocalDate(year: 2027, month: 5, day: 14), .ongoing(day: 3, of: 7)),
        (LocalDate(year: 2027, month: 5, day: 18), .ongoing(day: 7, of: 7)),
        (LocalDate(year: 2027, month: 5, day: 19), .past),
    ])
    func phase(today: LocalDate, expected: TripPhase) {
        let lisbon = trip("lisbon", from: LocalDate(year: 2027, month: 5, day: 12), to: LocalDate(year: 2027, month: 5, day: 18))
        #expect(lisbon.phase(on: today, calendar: Self.calendar) == expected)
    }

    @Test func countsDaysAcrossDaylightSavingChange() {
        let weekend = trip("weekend", from: LocalDate(year: 2027, month: 3, day: 27), to: LocalDate(year: 2027, month: 3, day: 29))
        #expect(weekend.phase(on: LocalDate(year: 2027, month: 3, day: 29), calendar: Self.calendar) == .ongoing(day: 3, of: 3))
    }

    @Test func singleDayTripLastsOneDay() {
        let day = LocalDate(year: 2027, month: 6, day: 1)
        #expect(trip("day", from: day, to: day).phase(on: day, calendar: Self.calendar) == .ongoing(day: 1, of: 1))
    }

    @Test func featuresOngoingTripBeforeUpcomingOnes() {
        let today = LocalDate(year: 2027, month: 5, day: 14)
        let sections = TripSections(
            trips: [
                trip("zakopane", from: LocalDate(year: 2027, month: 12, day: 29), to: LocalDate(year: 2028, month: 1, day: 2)),
                trip("lisbon", from: LocalDate(year: 2027, month: 5, day: 12), to: LocalDate(year: 2027, month: 5, day: 18)),
                trip("berlin", from: LocalDate(year: 2026, month: 3, day: 14), to: LocalDate(year: 2026, month: 3, day: 16)),
                trip("mazury", from: LocalDate(year: 2026, month: 8, day: 8), to: LocalDate(year: 2026, month: 8, day: 15)),
                trip("gdansk", from: LocalDate(year: 2027, month: 6, day: 1), to: LocalDate(year: 2027, month: 6, day: 3)),
            ],
            today: today
        )

        #expect(sections.featured?.id == "lisbon")
        #expect(sections.planned.map(\.id) == ["gdansk", "zakopane"])
        #expect(sections.past.map(\.id) == ["mazury", "berlin"])
    }

    @Test func featuresNearestUpcomingTripWhenNothingIsOngoing() {
        let sections = TripSections(
            trips: [
                trip("zakopane", from: LocalDate(year: 2027, month: 12, day: 29), to: LocalDate(year: 2028, month: 1, day: 2)),
                trip("gdansk", from: LocalDate(year: 2027, month: 6, day: 1), to: LocalDate(year: 2027, month: 6, day: 3)),
            ],
            today: LocalDate(year: 2027, month: 5, day: 1)
        )

        #expect(sections.featured?.id == "gdansk")
        #expect(sections.planned.map(\.id) == ["zakopane"])
        #expect(!sections.isEmpty)
    }

    @Test func treatsOnlyPastTripsAsNotEmpty() {
        let sections = TripSections(
            trips: [trip("berlin", from: LocalDate(year: 2026, month: 3, day: 14), to: LocalDate(year: 2026, month: 3, day: 16))],
            today: LocalDate(year: 2027, month: 5, day: 1)
        )

        #expect(sections.featured == nil)
        #expect(!sections.isEmpty)
        #expect(TripSections(trips: [], today: LocalDate(year: 2027, month: 5, day: 1)).isEmpty)
    }

    @Test(arguments: [
        (1, "1 noc"), (2, "2 noce"), (4, "4 noce"), (5, "5 nocy"), (12, "12 nocy"), (22, "22 noce"), (25, "25 nocy"),
    ])
    func pluralizesNights(count: Int, expected: String) {
        #expect(PolishPlural.nights(count) == expected)
    }

    @Test func formatsShortRanges() {
        let newYear = (LocalDate(year: 2026, month: 12, day: 29), LocalDate(year: 2027, month: 1, day: 2))
        let mazury = (LocalDate(year: 2026, month: 8, day: 8), LocalDate(year: 2026, month: 8, day: 15))

        #expect(TripDateFormat.shortRange(newYear.0, newYear.1) == "29 gru – 2 sty")
        #expect(TripDateFormat.shortRange(mazury.0, mazury.1, includesYear: true) == "8–15 sie 2026")
    }

    @Test func picksWeekdayPhrase() {
        #expect(TripDateFormat.weekdayPhrase(LocalDate(year: 2027, month: 5, day: 12), calendar: Self.calendar) == "w środę")
        #expect(TripDateFormat.weekdayPhrase(LocalDate(year: 2027, month: 5, day: 11), calendar: Self.calendar) == "we wtorek")
    }
}
