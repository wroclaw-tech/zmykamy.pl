import Foundation

struct InspirationDestination: Identifiable, Equatable {
    let name: String
    let country: String
    let latitude: Double
    let longitude: Double
    let climate: VacationClimate
    let flightMinutes: Int
    let bestMonths: Set<Int>
    let highs: [Int]
    let tags: [String]

    var id: String { name }

    func high(in month: Int) -> Int {
        highs[month - 1]
    }

    var tripDestination: TripDestination {
        TripDestination(name: name, country: country, latitude: latitude, longitude: longitude)
    }
}

struct InspirationFilters: Equatable {
    static let flightHourOptions = [2, 4, 6, 12]
    static let warmHigh = 22

    var climate: VacationClimate?
    var maxFlightHours: Int?
    var month: Int?
    var warmOnly = false

    var isEmpty: Bool {
        self == InspirationFilters()
    }

    func matches(_ destination: InspirationDestination, currentMonth: Int) -> Bool {
        if let climate, destination.climate != climate { return false }
        if let maxFlightHours, destination.flightMinutes > maxFlightHours * 60 { return false }
        if let month, !destination.bestMonths.contains(month) { return false }
        if warmOnly, destination.high(in: month ?? currentMonth) < Self.warmHigh { return false }
        return true
    }

    func apply(to destinations: [InspirationDestination], currentMonth: Int) -> [InspirationDestination] {
        destinations.filter { matches($0, currentMonth: currentMonth) }
    }
}

extension Array where Element == InspirationDestination {
    func draw(excluding current: InspirationDestination?) -> InspirationDestination? {
        var generator = SystemRandomNumberGenerator()
        return draw(excluding: current, using: &generator)
    }

    func draw<G: RandomNumberGenerator>(excluding current: InspirationDestination?, using generator: inout G) -> InspirationDestination? {
        let others = filter { $0 != current }
        return (others.isEmpty ? self : others).randomElement(using: &generator)
    }
}

enum InspirationFormat {
    private static let months = ["Styczeń", "Luty", "Marzec", "Kwiecień", "Maj", "Czerwiec",
                                 "Lipiec", "Sierpień", "Wrzesień", "Październik", "Listopad", "Grudzień"]
    private static let monthsLocative = ["styczniu", "lutym", "marcu", "kwietniu", "maju", "czerwcu",
                                         "lipcu", "sierpniu", "wrześniu", "październiku", "listopadzie", "grudniu"]

    static func month(_ month: Int) -> String {
        months[month - 1]
    }

    static func flightTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        let time = switch (hours, rest) {
        case (0, _): "\(rest) min"
        case (_, 0): "\(hours) h"
        default: "\(hours) h \(rest) min"
        }
        return "\(time) lotu"
    }

    static func maxFlight(hours: Int) -> String {
        "Do \(hours) h lotu"
    }

    static func weather(_ destination: InspirationDestination, in month: Int) -> String {
        "\(destination.high(in: month))° w \(monthsLocative[month - 1])"
    }
}
