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

nonisolated struct TripWeather: Codable, Equatable, Sendable {
    let days: [DayWeather]

    func forecast(on date: LocalDate) -> DayWeather? {
        days.first { $0.date == date }
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
