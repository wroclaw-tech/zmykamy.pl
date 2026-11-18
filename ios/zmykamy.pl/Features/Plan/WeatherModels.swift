import SwiftUI

/// Daily forecast for one trip day at the place the plan puts the group that day.
nonisolated struct DayWeather: Codable, Equatable, Sendable {
    let date: LocalDate
    let place: String?
    let latitude: Double
    let longitude: Double
    let weatherCode: Int
    let temperatureMax: Double
    let temperatureMin: Double
    let precipitationProbability: Int?

    var condition: WeatherCondition {
        WeatherCondition(code: weatherCode)
    }

    /// "21°", the rounded daily maximum.
    var temperatureText: String {
        "\(Int(temperatureMax.rounded()))°"
    }
}

/// Weather right now at the place the plan puts the group today.
nonisolated struct CurrentWeather: Codable, Equatable, Sendable {
    let date: LocalDate
    let place: String?
    let temperature: Double
    let weatherCode: Int

    var condition: WeatherCondition {
        WeatherCondition(code: weatherCode)
    }

    var temperatureText: String {
        "\(Int(temperature.rounded()))°"
    }
}

/// Weather usually seen on the trip dates, for trips too far ahead for a forecast.
nonisolated struct TypicalWeather: Codable, Equatable, Sendable {
    let place: String?
    let weatherCode: Int
    let temperatureMax: Double
    let temperatureMin: Double

    var condition: WeatherCondition {
        WeatherCondition(code: weatherCode)
    }

    var temperatureText: String {
        "\(Int(temperatureMax.rounded()))°"
    }
}

nonisolated struct TripWeather: Codable, Equatable, Sendable {
    let days: [DayWeather]
    let current: CurrentWeather?
    let typical: TypicalWeather?
    let forecastAvailableFrom: LocalDate?

    func forecast(on date: LocalDate) -> DayWeather? {
        days.first { $0.date == date }
    }

    /// The usual weather for a day the forecast does not reach.
    func typical(on date: LocalDate) -> TypicalWeather? {
        guard forecast(on: date) == nil, let typical else { return nil }
        if let lastForecast = days.last, date <= lastForecast.date { return nil }
        return typical
    }

    /// What the trip's weather tile shows on `today`, or nil when there is nothing to show.
    func summary(today: LocalDate, tripStart: LocalDate, followingDays: Int = 3) -> TripWeatherSummary? {
        if let current {
            let later = days.filter { $0.date > current.date }
            return .now(current, today: forecast(on: current.date), next: Array(later.prefix(followingDays)))
        }
        let upcoming = days.filter { $0.date >= today }
        if let first = upcoming.first {
            return .forecast(first, next: Array(upcoming.dropFirst().prefix(followingDays)))
        }
        if let typical, tripStart > today {
            let leadDays = forecastAvailableFrom.map { $0.days(until: tripStart) }
            return .typical(typical, tripStart: tripStart, forecastLeadDays: leadDays)
        }
        return nil
    }
}

nonisolated enum TripWeatherSummary: Equatable, Sendable {
    /// During the trip: now, today's range and the next days.
    case now(CurrentWeather, today: DayWeather?, next: [DayWeather])
    /// Before the trip, once the forecast reaches it: the first trip day and the ones after.
    case forecast(DayWeather, next: [DayWeather])
    /// Before the forecast reaches the trip; `forecastLeadDays` is how long before the start it will.
    case typical(TypicalWeather, tripStart: LocalDate, forecastLeadDays: Int?)
}

nonisolated enum WeatherFormat {
    private static let monthsLocative = [
        "styczniu", "lutym", "marcu", "kwietniu", "maju", "czerwcu",
        "lipcu", "sierpniu", "wrześniu", "październiku", "listopadzie", "grudniu",
    ]

    /// "W maju zwykle słonecznie", "We wrześniu zwykle deszczowo".
    static func usually(_ condition: WeatherCondition, in date: LocalDate) -> String {
        let month = monthsLocative[min(max(date.month, 1), 12) - 1]
        let preposition = month.hasPrefix("w") ? "We" : "W"
        return "\(preposition) \(month) zwykle \(condition.usualPhrase)"
    }

    /// "Noce ok. 14°. Prognoza będzie dostępna 15 dni przed wylotem."
    static func typicalDetails(_ typical: TypicalWeather, forecastLeadDays: Int?) -> String {
        let nights = "Noce ok. \(Int(typical.temperatureMin.rounded()))°."
        guard let days = forecastLeadDays, days > 0 else { return nights }
        let lead = PolishPlural.form(days, one: "1 dzień", few: "\(days) dni", many: "\(days) dni")
        return "\(nights) Prognoza będzie dostępna \(lead) przed wylotem."
    }

    /// "Słonecznie · 26° / 15°".
    static func range(_ day: DayWeather) -> String {
        "\(day.condition.label) · \(day.temperatureText) / \(Int(day.temperatureMin.rounded()))°"
    }
}

/// Weather grouped from WMO codes, as Open-Meteo reports them.
nonisolated enum WeatherCondition: Equatable, Sendable {
    case clear, partlyCloudy, cloudy, fog, rain, snow, thunderstorm

    init(code: Int) {
        switch code {
        case 0: self = .clear
        case 1, 2: self = .partlyCloudy
        case 45, 48: self = .fog
        case 51...67, 80...82: self = .rain
        case 71...77, 85, 86: self = .snow
        case 95...99: self = .thunderstorm
        default: self = .cloudy
        }
    }

    var label: String {
        switch self {
        case .clear: "Słonecznie"
        case .partlyCloudy: "Częściowe zachmurzenie"
        case .cloudy: "Pochmurno"
        case .fog: "Mgła"
        case .rain: "Deszcz"
        case .snow: "Śnieg"
        case .thunderstorm: "Burza"
        }
    }

    /// Completes "W maju zwykle …".
    var usualPhrase: String {
        switch self {
        case .clear: "słonecznie"
        case .partlyCloudy: "pogodnie z chmurami"
        case .cloudy: "pochmurno"
        case .fog: "mgliście"
        case .rain: "deszczowo"
        case .snow: "śnieżnie"
        case .thunderstorm: "burzowo"
        }
    }

    @MainActor var icon: ImageResource {
        switch self {
        case .clear: .sunny
        case .partlyCloudy: .partlyCloudyDay
        case .cloudy: .cloud
        case .fog: .foggy
        case .rain: .rainy
        case .snow: .weatherSnowy
        case .thunderstorm: .thunderstorm
        }
    }
}
