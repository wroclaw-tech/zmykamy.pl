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
        "place":"Rossio","latitude":38.7139,"longitude":-9.1394,"icon":"train","author":{"userId":"u1","name":"Ola"}}],\
        "info":[{"id":"i1","title":"Nocleg","text":"Alfama","icon":"bed","author":null}]}
        """
        let plan = try APIClient.decoder.decode(TripPlan.self, from: Data(json.utf8))

        #expect(plan.points.first?.date == LocalDate(year: 2027, month: 5, day: 14))
        #expect(plan.points.first?.time == PlanTime(hour: 9, minute: 12))
        #expect(plan.points.first?.icon == .train)
        #expect(plan.points.first?.subtitle == "Rossio")
        #expect(plan.points.first?.coordinate == PlanCoordinate(latitude: 38.7139, longitude: -9.1394))
        #expect(plan.info.first?.author == nil)
    }

    @Test func readsPlansCachedBeforePointsHadCoordinates() throws {
        let json = """
        {"points":[{"id":"p1","date":"2027-05-14","time":"09:12","title":"Spacer","description":null,\
        "place":null,"icon":"park","author":null}],"info":[]}
        """
        let plan = try APIClient.decoder.decode(TripPlan.self, from: Data(json.utf8))

        #expect(plan.points.first?.coordinate == nil)
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
            coordinate: nil,
            icon: .park
        )
        let json = try #require(String(data: JSONEncoder().encode(request), encoding: .utf8))

        #expect(json.contains("\"description\":null"))
        #expect(json.contains("\"place\":null"))
        #expect(json.contains("\"latitude\":null"))
        #expect(json.contains("\"longitude\":null"))
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
                .fixture("a", on: first, at: PlanTime(hour: 9, minute: 0)),
                .fixture("b", on: second, at: PlanTime(hour: 10, minute: 0)),
            ],
            info: []
        )

        #expect(plan.points(on: first).map(\.id) == ["a"])
        #expect(plan.points(on: LocalDate(year: 2027, month: 5, day: 14)).isEmpty)
    }
}
