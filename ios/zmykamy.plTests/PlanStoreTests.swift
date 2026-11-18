import Foundation
import Testing
@testable import zmykamy_pl

@MainActor
@Suite(.offlineCache)
struct PlanStoreTests {
    let backend = FakeBackend()
    let trip = Trip.fixture()

    private let monday = LocalDate(year: 2027, month: 5, day: 12)
    private let tuesday = LocalDate(year: 2027, month: 5, day: 13)

    private func store() -> PlanStore {
        PlanStore(api: backend.api(backend.signedIn()))
    }

    @Test func keepsPointsInChronologicalOrderAsTheyAreAdded() async throws {
        backend.on("GET", "trips/t1/plan", returning: TripPlan(
            points: [.fixture("lunch", on: monday, at: PlanTime(hour: 13, minute: 0))],
            info: []
        ))
        let plan = store()
        try await plan.load(trip)

        for point in [
            PlanPoint.fixture("breakfast", on: monday, at: PlanTime(hour: 8, minute: 30)),
            PlanPoint.fixture("museum", on: tuesday, at: PlanTime(hour: 10, minute: 0)),
            PlanPoint.fixture("dinner", on: monday, at: PlanTime(hour: 19, minute: 0)),
        ] {
            backend.on("POST", "trips/t1/plan/points", returning: point)
            try await plan.addPoint(Self.request(for: point), to: trip)
        }

        #expect(plan.plan(for: trip)?.points.map(\.id) == ["breakfast", "lunch", "dinner", "museum"])
    }

    @Test func reordersAPointMovedToAnotherTime() async throws {
        let early = PlanPoint.fixture("early", on: monday, at: PlanTime(hour: 8, minute: 0))
        let late = PlanPoint.fixture("late", on: monday, at: PlanTime(hour: 18, minute: 0))
        backend.on("GET", "trips/t1/plan", returning: TripPlan(points: [early, late], info: []))
        let moved = PlanPoint.fixture("early", on: monday, at: PlanTime(hour: 21, minute: 0))
        backend.on("PATCH", "trips/t1/plan/points/early", returning: moved)
        let plan = store()
        try await plan.load(trip)

        try await plan.update(early, with: Self.request(for: moved), in: trip)

        #expect(plan.plan(for: trip)?.points.map(\.id) == ["late", "early"])
    }

    @Test func showsTheLastSeenPlanOffline() async throws {
        backend.on("GET", "trips/t1/plan", returning: TripPlan(points: [.fixture("a", on: monday, at: PlanTime(hour: 9, minute: 0))], info: []))
        backend.on("POST", "trips/t1/plan/points", returning: PlanPoint.fixture("b", on: monday, at: PlanTime(hour: 10, minute: 0)))
        let plan = store()
        try await plan.load(trip)
        try await plan.addPoint(Self.request(for: .fixture("b", on: monday, at: PlanTime(hour: 10, minute: 0))), to: trip)

        backend.goOffline()
        let relaunched = store()
        try await relaunched.load(trip)

        #expect(relaunched.plan(for: trip)?.points.map(\.id) == ["a", "b"])
    }

    @Test func failsOfflineWhenThePlanWasNeverOpened() async {
        backend.goOffline()

        await #expect(throws: APIError.network) {
            try await store().load(trip)
        }
    }

    @Test func showsTheForecastForTripDays() async throws {
        backend.on("GET", "trips/t1/weather", json: Self.weatherJSON)
        let plan = store()

        await plan.loadWeather(trip)

        let forecast = try #require(plan.weather(for: trip)?.forecast(on: monday))
        #expect(forecast.place == "Sintra")
        #expect(forecast.condition == .clear)
    }

    @Test func keepsTheLastForecastWhenOffline() async {
        backend.on("GET", "trips/t1/weather", json: Self.weatherJSON)
        await store().loadWeather(trip)

        backend.goOffline()
        let relaunched = store()
        await relaunched.loadWeather(trip)

        #expect(relaunched.weather(for: trip)?.days.map(\.date) == [monday])
    }

    @Test func keepsTheShownForecastWhenRefreshingFails() async {
        backend.on("GET", "trips/t1/weather", json: Self.weatherJSON)
        let plan = store()
        await plan.loadWeather(trip)

        backend.on("GET", "trips/t1/weather", status: 502, json: #"{"error":{"code":"internal_error","message":"x"}}"#)
        await plan.loadWeather(trip)

        #expect(plan.weather(for: trip)?.days.count == 1)
    }

    @Test func sendsThePickedPlaceCoordinates() async throws {
        let point = PlanPoint.fixture("pena", on: monday, at: PlanTime(hour: 10, minute: 30), coordinate: PlanCoordinate(latitude: 38.7876, longitude: -9.3906))
        backend.on("POST", "trips/t1/plan/points", returning: point)
        let plan = store()

        try await plan.addPoint(Self.request(for: point), to: trip)

        let sent = try #require(backend.requests("POST", "trips/t1/plan/points").first?.json)
        #expect(sent["latitude"] as? Double == 38.7876)
        #expect(sent["longitude"] as? Double == -9.3906)
        #expect(plan.plan(for: trip)?.points.first?.coordinate == point.coordinate)
    }

    private static let weatherJSON = """
    {"days":[{"date":"2027-05-12","place":"Sintra","latitude":38.8,"longitude":-9.39,"weatherCode":0,\
    "temperatureMax":21.4,"temperatureMin":13.1,"precipitationProbability":5}]}
    """

    private static func request(for point: PlanPoint) -> PlanPointRequest {
        PlanPointRequest(
            date: point.date,
            time: point.time,
            title: point.title,
            description: nil,
            place: nil,
            coordinate: point.coordinate,
            icon: point.icon
        )
    }
}
