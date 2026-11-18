import SwiftUI

/// Navigation apps a plan point can be opened in. Universal links open the app when it is
/// installed and the website otherwise.
nonisolated enum MapsApp: CaseIterable, Identifiable, Sendable {
    case apple, google, waze

    var id: Self { self }

    var title: String {
        switch self {
        case .apple: "Apple Maps"
        case .google: "Google Maps"
        case .waze: "Waze"
        }
    }

    @MainActor var icon: ImageResource {
        switch self {
        case .apple: .map
        case .google: .directions
        case .waze: .directionsCar
        }
    }

    func directionsURL(to coordinate: PlanCoordinate) -> URL? {
        let location = "\(coordinate.latitude),\(coordinate.longitude)"
        var components: URLComponents?
        switch self {
        case .apple:
            components = URLComponents(string: "https://maps.apple.com/")
            components?.queryItems = [URLQueryItem(name: "daddr", value: location)]
        case .google:
            components = URLComponents(string: "https://www.google.com/maps/dir/")
            components?.queryItems = [
                URLQueryItem(name: "api", value: "1"),
                URLQueryItem(name: "destination", value: location),
            ]
        case .waze:
            components = URLComponents(string: "https://waze.com/ul")
            components?.queryItems = [
                URLQueryItem(name: "ll", value: location),
                URLQueryItem(name: "navigate", value: "yes"),
            ]
        }
        return components?.url
    }
}

/// When the group travels between the points of one day.
nonisolated struct PlanDayTimeline: Sendable {
    /// How long before a point navigation to it is suggested.
    static let leadMinutes = 30

    private static let transportIcons: Set<PlanIcon> = [
        .flight, .flightTakeoff, .flightLand, .train, .tram, .directionsCar, .localTaxi,
    ]

    let day: LocalDate
    let points: [PlanPoint]

    init(day: LocalDate, points: [PlanPoint]) {
        self.day = day
        self.points = points.filter { $0.date == day }.sorted { $0.time < $1.time }
    }

    /// Lead time before the point, but not before the previous point starts.
    func navigationStart(for point: PlanPoint) -> PlanTime {
        let start = point.time.minutes - Self.leadMinutes
        guard let index = points.firstIndex(where: { $0.id == point.id }), index > 0 else {
            return PlanTime(minutes: start)
        }
        return PlanTime(minutes: max(start, points[index - 1].time.minutes))
    }

    /// The point the group is heading to at `now`, or riding when the point is a means of
    /// transport, until it is time to head to the next one.
    func travellingPointID(at now: Date, calendar: Calendar) -> PlanPoint.ID? {
        guard LocalDate(now, calendar: calendar) == day else { return nil }
        let current = PlanTime(now, calendar: calendar).minutes
        for (index, point) in points.enumerated() {
            let end: Int
            if Self.transportIcons.contains(point.icon) {
                end = index + 1 < points.count ? navigationStart(for: points[index + 1]).minutes : 24 * 60
            } else {
                end = point.time.minutes + 1
            }
            if navigationStart(for: point).minutes <= current && current < end {
                return point.id
            }
        }
        return nil
    }

    /// Whether navigation to the point is still ahead of `now`.
    func navigationIsAhead(for point: PlanPoint, at now: Date, calendar: Calendar) -> Bool {
        let today = LocalDate(now, calendar: calendar)
        if day != today {
            return today < day
        }
        return PlanTime(now, calendar: calendar) < navigationStart(for: point)
    }
}
