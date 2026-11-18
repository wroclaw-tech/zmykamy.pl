import Foundation
import Testing
@testable import zmykamy_pl

struct PlanNavigationTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Lisbon")!
        return calendar
    }()

    private static let day = LocalDate(year: 2027, month: 5, day: 14)
    private static let sintra = PlanCoordinate(latitude: 38.8, longitude: -9.39)

    /// The Figma day: a train, a palace and dinner.
    private static let timeline = PlanDayTimeline(day: day, points: [
        .fixture("dinner", on: day, at: PlanTime(hour: 20, minute: 0), icon: .restaurant),
        .fixture("train", on: day, at: PlanTime(hour: 9, minute: 12), icon: .train, coordinate: sintra),
        .fixture("pena", on: day, at: PlanTime(hour: 10, minute: 30), icon: .castle, coordinate: sintra),
        .fixture("other-day", on: day.adding(days: 1), at: PlanTime(hour: 9, minute: 0)),
    ])

    private static func at(_ hour: Int, _ minute: Int, on date: LocalDate = day) -> Date {
        calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day, hour: hour, minute: minute))!
    }

    private static func point(_ id: String) -> PlanPoint {
        timeline.points.first { $0.id == id }!
    }

    @Test func keepsOnlyTheDaysPointsInOrder() {
        #expect(Self.timeline.points.map(\.id) == ["train", "pena", "dinner"])
    }

    @Test(arguments: [
        ("train", PlanTime(hour: 8, minute: 42)),
        ("pena", PlanTime(hour: 10, minute: 0)),
        ("dinner", PlanTime(hour: 19, minute: 30)),
    ])
    func suggestsNavigationHalfAnHourAhead(id: String, start: PlanTime) {
        #expect(Self.timeline.navigationStart(for: Self.point(id)) == start)
    }

    @Test func doesNotSuggestNavigationBeforeThePreviousPointStarts() {
        let timeline = PlanDayTimeline(day: Self.day, points: [
            .fixture("coffee", on: Self.day, at: PlanTime(hour: 10, minute: 0)),
            .fixture("museum", on: Self.day, at: PlanTime(hour: 10, minute: 15)),
        ])

        #expect(timeline.navigationStart(for: timeline.points[1]) == PlanTime(hour: 10, minute: 0))
    }

    @Test(arguments: [
        (8, 30, nil),
        (8, 42, "train"),
        (9, 41, "train"),
        (9, 59, "train"),
        (10, 0, "pena"),
        (10, 30, "pena"),
        (10, 31, nil),
        (19, 45, "dinner"),
        (20, 1, nil),
    ] as [(Int, Int, String?)])
    func highlightsThePointTheGroupIsTravellingTo(hour: Int, minute: Int, expected: String?) {
        #expect(Self.timeline.travellingPointID(at: Self.at(hour, minute), calendar: Self.calendar) == expected)
    }

    @Test func highlightsNothingOnOtherDays() {
        let nextDay = Self.at(9, 41, on: Self.day.adding(days: 1))

        #expect(Self.timeline.travellingPointID(at: nextDay, calendar: Self.calendar) == nil)
    }

    @Test func keepsTheLastTransportOfTheDayHighlightedUntilMidnight() {
        let timeline = PlanDayTimeline(day: Self.day, points: [
            .fixture("night-train", on: Self.day, at: PlanTime(hour: 22, minute: 0), icon: .train),
        ])

        #expect(timeline.travellingPointID(at: Self.at(23, 59), calendar: Self.calendar) == "night-train")
    }

    @Test func tellsWhetherNavigationIsStillAhead() {
        let pena = Self.point("pena")

        #expect(Self.timeline.navigationIsAhead(for: pena, at: Self.at(9, 41), calendar: Self.calendar))
        #expect(!Self.timeline.navigationIsAhead(for: pena, at: Self.at(10, 0), calendar: Self.calendar))
        #expect(Self.timeline.navigationIsAhead(for: pena, at: Self.at(23, 0, on: Self.day.adding(days: -1)), calendar: Self.calendar))
        #expect(!Self.timeline.navigationIsAhead(for: pena, at: Self.at(8, 0, on: Self.day.adding(days: 1)), calendar: Self.calendar))
    }

    @Test(arguments: [
        (MapsApp.apple, "https://maps.apple.com/?daddr=38.7876,-9.3906"),
        (MapsApp.google, "https://www.google.com/maps/dir/?api=1&destination=38.7876,-9.3906"),
        (MapsApp.waze, "https://waze.com/ul?ll=38.7876,-9.3906&navigate=yes"),
    ])
    func opensDirectionsToThePlace(app: MapsApp, url: String) {
        let pena = PlanCoordinate(latitude: 38.7876, longitude: -9.3906)

        #expect(app.directionsURL(to: pena)?.absoluteString == url)
    }
}

struct WeatherModelsTests {
    @Test func decodesTheForecastFromTheApi() throws {
        let json = """
        {"days":[{"date":"2027-05-14","place":"Sintra","latitude":38.8,"longitude":-9.39,"weatherCode":61,\
        "temperatureMax":20.5,"temperatureMin":12.5,"precipitationProbability":null}]}
        """
        let weather = try APIClient.decoder.decode(TripWeather.self, from: Data(json.utf8))

        let day = try #require(weather.forecast(on: LocalDate(year: 2027, month: 5, day: 14)))
        #expect(day.condition == .rain)
        #expect(day.temperatureText == "21°")
        #expect(day.precipitationProbability == nil)
        #expect(weather.forecast(on: LocalDate(year: 2027, month: 5, day: 15)) == nil)
    }

    @Test(arguments: [
        (0, WeatherCondition.clear),
        (2, .partlyCloudy),
        (3, .cloudy),
        (45, .fog),
        (53, .rain),
        (81, .rain),
        (73, .snow),
        (86, .snow),
        (95, .thunderstorm),
    ])
    func groupsWmoCodes(code: Int, condition: WeatherCondition) {
        #expect(WeatherCondition(code: code) == condition)
    }

    @Test(arguments: [(-0.4, "0°"), (-2.6, "-3°"), (21.49, "21°")])
    func roundsTheMaximumTemperature(maximum: Double, text: String) {
        let day = DayWeather(
            date: LocalDate(year: 2027, month: 1, day: 1),
            place: nil,
            latitude: 0,
            longitude: 0,
            weatherCode: 0,
            temperatureMax: maximum,
            temperatureMin: maximum,
            precipitationProbability: nil
        )

        #expect(day.temperatureText == text)
    }

    @Test func decodesCurrentAndTypicalWeather() throws {
        let json = """
        {"days":[],"current":{"date":"2027-05-14","place":"Lizbona","latitude":38.72,"longitude":-9.14,\
        "temperature":24.3,"weatherCode":0},"typical":null,"forecastAvailableFrom":"2027-04-27"}
        """
        let weather = try APIClient.decoder.decode(TripWeather.self, from: Data(json.utf8))

        #expect(weather.current?.temperatureText == "24°")
        #expect(weather.typical == nil)
        #expect(weather.forecastAvailableFrom == LocalDate(year: 2027, month: 4, day: 27))
    }

    private static let start = LocalDate(year: 2027, month: 5, day: 12)

    private static func day(_ offset: Int, max: Double = 25) -> DayWeather {
        DayWeather(
            date: start.adding(days: offset),
            place: "Lizbona",
            latitude: 38.72,
            longitude: -9.14,
            weatherCode: 0,
            temperatureMax: max,
            temperatureMin: 15,
            precipitationProbability: nil
        )
    }

    @Test func showsNowAndTheNextThreeDaysDuringTheTrip() throws {
        let current = CurrentWeather(date: Self.start.adding(days: 2), place: "Sintra", temperature: 24, weatherCode: 0)
        let weather = TripWeather(days: (0...6).map { Self.day($0) }, current: current, typical: nil, forecastAvailableFrom: nil)

        let summary = weather.summary(today: Self.start.adding(days: 2), tripStart: Self.start)

        #expect(summary == .now(current, today: Self.day(2), next: [Self.day(3), Self.day(4), Self.day(5)]))
    }

    @Test func showsTheFirstTripDayOnceTheForecastReachesIt() {
        let weather = TripWeather(days: [Self.day(0), Self.day(1)], current: nil, typical: nil, forecastAvailableFrom: nil)

        let summary = weather.summary(today: Self.start.adding(days: -3), tripStart: Self.start)

        #expect(summary == .forecast(Self.day(0), next: [Self.day(1)]))
    }

    @Test func showsTheUsualWeatherBeforeTheForecastReachesTheTrip() {
        let typical = TypicalWeather(place: "Pekin", weatherCode: 0, temperatureMax: 28.6, temperatureMin: 15.2)
        let weather = TripWeather(days: [], current: nil, typical: typical, forecastAvailableFrom: Self.start.adding(days: -15))

        let summary = weather.summary(today: Self.start.adding(days: -40), tripStart: Self.start)

        #expect(summary == .typical(typical, tripStart: Self.start, forecastLeadDays: 15))
    }

    @Test func showsNothingAfterTheTrip() {
        let weather = TripWeather(days: [], current: nil, typical: nil, forecastAvailableFrom: nil)

        #expect(weather.summary(today: Self.start.adding(days: 10), tripStart: Self.start) == nil)
    }

    @Test(arguments: [
        (5, WeatherCondition.clear, "W maju zwykle słonecznie"),
        (9, .rain, "We wrześniu zwykle deszczowo"),
        (2, .snow, "W lutym zwykle śnieżnie"),
    ])
    func describesTheUsualWeatherInPolish(month: Int, condition: WeatherCondition, text: String) {
        #expect(WeatherFormat.usually(condition, in: LocalDate(year: 2027, month: month, day: 1)) == text)
    }

    @Test(arguments: [
        (15, "Noce ok. 14°. Prognoza będzie dostępna 15 dni przed wylotem."),
        (1, "Noce ok. 14°. Prognoza będzie dostępna 1 dzień przed wylotem."),
        (nil, "Noce ok. 14°."),
    ] as [(Int?, String)])
    func tellsWhenTheForecastArrives(leadDays: Int?, text: String) {
        let typical = TypicalWeather(place: nil, weatherCode: 0, temperatureMax: 22, temperatureMin: 13.6)

        #expect(WeatherFormat.typicalDetails(typical, forecastLeadDays: leadDays) == text)
    }

    @Test func formatsTheDailyRange() {
        #expect(WeatherFormat.range(Self.day(0, max: 26.4)) == "Słonecznie · 26° / 15°")
    }
}

struct TripPlaceTileTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Lisbon")!
        return calendar
    }()

    private static let day = LocalDate(year: 2027, month: 5, day: 14)
    private static let place = PlanCoordinate(latitude: 38.7, longitude: -9.1)

    private static let plan = TripPlan(
        points: [
            .fixture("pena", on: day, at: PlanTime(hour: 10, minute: 30), coordinate: place),
            .fixture("lunch", on: day, at: PlanTime(hour: 13, minute: 0)),
            .fixture("dinner", on: day, at: PlanTime(hour: 20, minute: 0), coordinate: place),
        ],
        info: []
    )

    private static func at(_ hour: Int, on date: LocalDate = day) -> Date {
        calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day, hour: hour))!
    }

    @Test(arguments: [(9, "pena"), (11, "dinner"), (21, "pena")])
    func pointsToTheNextPlaceFromThePlan(hour: Int, expected: String) {
        #expect(Self.plan.nextLocatedPoint(at: Self.at(hour), calendar: Self.calendar)?.id == expected)
    }

    @Test func pointsToNothingWithoutLocatedPlaces() {
        let plan = TripPlan(points: [.fixture("lunch", on: Self.day, at: PlanTime(hour: 13, minute: 0))], info: [])

        #expect(plan.nextLocatedPoint(at: Self.at(9), calendar: Self.calendar) == nil)
    }
}
