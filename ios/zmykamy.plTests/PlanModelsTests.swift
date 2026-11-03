import Foundation
import Testing
@testable import zmykamy_pl

struct PlanModelsTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw")!
        return calendar
    }()

    private func trip(role: TripRole = .participant, from start: LocalDate, to end: LocalDate) -> Trip {
        Trip(
            id: "t1",
            name: "Lizbona",
            destination: nil,
            startDate: start,
            endDate: end,
            currency: "EUR",
            coverUrl: nil,
            myRole: role,
            members: []
        )
    }

    @Test func decodesPlanFromTheApi() throws {
        let json = """
        {"points":[{"id":"p1","date":"2027-05-14","time":"09:12","title":"Pociąg do Sintry","description":null,\
        "place":"Rossio","icon":"train","author":{"userId":"u1","name":"Ola"}}],\
        "info":[{"id":"i1","title":"Nocleg","text":"Alfama","icon":"bed","author":null}]}
        """
        let plan = try APIClient.decoder.decode(TripPlan.self, from: Data(json.utf8))

        #expect(plan.points.first?.date == LocalDate(year: 2027, month: 5, day: 14))
        #expect(plan.points.first?.time == PlanTime(hour: 9, minute: 12))
        #expect(plan.points.first?.icon == .train)
        #expect(plan.points.first?.subtitle == "Rossio")
        #expect(plan.info.first?.author == nil)
    }

    @Test func fallsBackToDefaultIconForUnknownKeys() throws {
        let icon = try JSONDecoder().decode(PlanIcon.self, from: Data("\"rocket\"".utf8))

        #expect(icon == .locationOn)
    }

    @Test func encodesClearedFieldsAsNull() throws {
        let request = PlanPointRequest(
            date: LocalDate(year: 2027, month: 5, day: 14),
            time: PlanTime(hour: 9, minute: 5),
            title: "Spacer",
            description: nil,
            place: nil,
            icon: .park
        )
        let json = try #require(String(data: JSONEncoder().encode(request), encoding: .utf8))

        #expect(json.contains("\"description\":null"))
        #expect(json.contains("\"place\":null"))
        #expect(json.contains("\"time\":\"09:05\""))
        #expect(json.contains("\"icon\":\"park\""))
    }

    @Test func listsEveryTripDay() {
        let trip = trip(from: LocalDate(year: 2027, month: 5, day: 30), to: LocalDate(year: 2027, month: 6, day: 2))

        let days = trip.days(calendar: Self.calendar)

        #expect(days.map(\.day) == [30, 31, 1, 2])
        #expect(days.last == LocalDate(year: 2027, month: 6, day: 2))
    }

    @Test func singleDayTripHasOneDay() {
        let day = LocalDate(year: 2027, month: 5, day: 12)

        #expect(trip(from: day, to: day).days(calendar: Self.calendar) == [day])
    }

    @Test func participantsEditOnlyTheirOwnEntries() {
        let day = LocalDate(year: 2027, month: 5, day: 12)
        let own = PlanAuthor(userId: "u1", name: "Ola")
        let other = PlanAuthor(userId: "u2", name: "Kuba")
        let participantTrip = trip(from: day, to: day)

        #expect(participantTrip.canEdit(authoredBy: own, userID: "u1"))
        #expect(!participantTrip.canEdit(authoredBy: other, userID: "u1"))
        #expect(!participantTrip.canEdit(authoredBy: nil, userID: "u1"))
    }

    @Test func organizersEditEverything() {
        let day = LocalDate(year: 2027, month: 5, day: 12)
        let organizerTrip = trip(role: .organizer, from: day, to: day)

        #expect(organizerTrip.canEdit(authoredBy: PlanAuthor(userId: "u2", name: "Kuba"), userID: "u1"))
        #expect(organizerTrip.canEdit(authoredBy: nil, userID: "u1"))
    }

    @Test func groupsPointsByDay() {
        let first = LocalDate(year: 2027, month: 5, day: 12)
        let second = LocalDate(year: 2027, month: 5, day: 13)
        let plan = TripPlan(
            points: [
                PlanPoint(id: "a", date: first, time: PlanTime(hour: 9, minute: 0), title: "A", description: nil, place: nil, icon: .park, author: nil),
                PlanPoint(id: "b", date: second, time: PlanTime(hour: 10, minute: 0), title: "B", description: nil, place: nil, icon: .park, author: nil),
            ],
            info: []
        )

        #expect(plan.points(on: first).map(\.id) == ["a"])
        #expect(plan.points(on: LocalDate(year: 2027, month: 5, day: 14)).isEmpty)
    }
}
