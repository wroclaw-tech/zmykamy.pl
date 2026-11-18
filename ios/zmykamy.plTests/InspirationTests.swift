import CoreGraphics
import Foundation
import Testing
@testable import zmykamy_pl

@MainActor
struct InspirationTests {
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    private func destination(
        _ name: String,
        climate: VacationClimate = .cities,
        flightMinutes: Int = 120,
        bestMonths: Set<Int> = [5],
        high: Int = 20
    ) -> InspirationDestination {
        InspirationDestination(
            name: name, country: "Kraj", latitude: 0, longitude: 0, climate: climate,
            flightMinutes: flightMinutes, bestMonths: bestMonths, highs: Array(repeating: high, count: 12), tags: []
        )
    }

    @Test func catalogIsCompleteAndConsistent() {
        let catalog = InspirationDestination.catalog

        #expect((40...60).contains(catalog.count))
        #expect(Set(catalog.map(\.name)).count == catalog.count)
        #expect(Set(catalog.map(\.climate)) == Set(VacationClimate.allCases))
        for destination in catalog {
            #expect(destination.highs.count == 12, "\(destination.name)")
            #expect(!destination.bestMonths.isEmpty && destination.bestMonths.isSubset(of: 1...12), "\(destination.name)")
            #expect((-90...90).contains(destination.latitude) && (-180...180).contains(destination.longitude), "\(destination.name)")
            #expect(destination.flightMinutes > 0 && destination.tags.count == 3, "\(destination.name)")
        }
    }

    @Test func emptyFiltersKeepEverything() {
        let pool = InspirationFilters().apply(to: InspirationDestination.catalog, currentMonth: 5)

        #expect(pool == InspirationDestination.catalog)
        #expect(InspirationFilters().isEmpty)
    }

    @Test func filtersByClimateFlightTimeAndMonth() {
        let lisbon = destination("Lizbona", climate: .cities, flightMinutes: 230, bestMonths: [5, 9])
        let prague = destination("Praga", climate: .cities, flightMinutes: 75, bestMonths: [12])
        let crete = destination("Kreta", climate: .beach, flightMinutes: 195, bestMonths: [5])
        let all = [lisbon, prague, crete]

        #expect(InspirationFilters(climate: .cities).apply(to: all, currentMonth: 1) == [lisbon, prague])
        #expect(InspirationFilters(maxFlightHours: 4).apply(to: all, currentMonth: 1) == [lisbon, prague, crete])
        #expect(InspirationFilters(maxFlightHours: 2).apply(to: all, currentMonth: 1) == [prague])
        #expect(InspirationFilters(month: 5).apply(to: all, currentMonth: 1) == [lisbon, crete])
        #expect(InspirationFilters(climate: .cities, maxFlightHours: 4, month: 5).apply(to: all, currentMonth: 1) == [lisbon])
    }

    @Test func warmOnlyChecksTheChosenMonthOrTheCurrentOne() {
        let reykjavik = InspirationDestination(
            name: "Reykjavík", country: "Islandia", latitude: 64.15, longitude: -21.94, climate: .ocean, flightMinutes: 230,
            bestMonths: [7], highs: [2, 3, 3, 6, 9, 12, 25, 13, 11, 7, 4, 3], tags: []
        )
        let tenerife = destination("Teneryfa", high: 24)
        let warm = InspirationFilters(warmOnly: true)

        #expect(warm.apply(to: [reykjavik, tenerife], currentMonth: 1) == [tenerife])
        #expect(warm.apply(to: [reykjavik, tenerife], currentMonth: 7) == [reykjavik, tenerife])
        #expect(InspirationFilters(month: 7, warmOnly: true).apply(to: [reykjavik, tenerife], currentMonth: 1) == [reykjavik])
    }

    @Test func impossibleFiltersLeaveNothingToDraw() {
        let filters = InspirationFilters(climate: .tropics, maxFlightHours: 2)
        let pool = filters.apply(to: InspirationDestination.catalog, currentMonth: 5)

        #expect(pool.isEmpty)
        #expect(pool.draw(excluding: nil) == nil)
    }

    @Test func drawNeverRepeatsTheCurrentDestinationWhenThereIsAChoice() {
        let lisbon = destination("Lizbona")
        let porto = destination("Porto")
        var generator = SeededGenerator(state: 42)

        for _ in 0..<50 {
            #expect([lisbon, porto].draw(excluding: lisbon, using: &generator) == porto)
        }
        #expect([lisbon].draw(excluding: lisbon, using: &generator) == lisbon)
    }

    @Test func drawPicksFromThePool() {
        let pool = InspirationFilters(climate: .mountains).apply(to: InspirationDestination.catalog, currentMonth: 5)
        var generator = SeededGenerator(state: 7)
        var drawn = Set<String>()

        for _ in 0..<200 {
            let destination = pool.draw(excluding: nil, using: &generator)
            #expect(destination?.climate == .mountains)
            drawn.insert(destination?.name ?? "")
        }
        #expect(drawn == Set(pool.map(\.name)))
    }

    @Test func plansATripToTheDrawnDestination() {
        let lisbon = InspirationDestination.catalog.first { $0.name == "Lizbona" }

        #expect(lisbon?.tripDestination == TripDestination(name: "Lizbona", country: "Portugalia", latitude: 38.72, longitude: -9.14))
    }

    @Test(arguments: [(230, "3 h 50 min lotu"), (120, "2 h lotu"), (55, "55 min lotu")])
    func formatsFlightTime(minutes: Int, text: String) {
        #expect(InspirationFormat.flightTime(minutes) == text)
    }

    @Test func formatsWeatherAndMonths() {
        let lisbon = InspirationDestination.catalog.first { $0.name == "Lizbona" }!

        #expect(InspirationFormat.weather(lisbon, in: 5) == "22° w maju")
        #expect(InspirationFormat.weather(lisbon, in: 2) == "16° w lutym")
        #expect(InspirationFormat.month(5) == "Maj")
        #expect(InspirationFormat.maxFlight(hours: 4) == "Do 4 h lotu")
    }

    @Test func centeringSpinsTheGlobeTowardsTheDestination() {
        let lisbon = InspirationDestination.catalog.first { $0.name == "Lizbona" }!
        let rotation = GlobeRotation.initial.centering(lisbon)
        let projection = GlobeProjection(rotation: rotation, center: .zero, radius: 100)
        let projected = projection.project(longitude: lisbon.longitude, latitude: lisbon.latitude)

        #expect(abs(rotation.longitude - GlobeRotation.initial.longitude) > 360)
        #expect(projected.isVisible)
        #expect(projected.point.x < 0 && projected.point.y < 0)
        #expect(hypot(projected.point.x, projected.point.y) < 40)
    }
}
