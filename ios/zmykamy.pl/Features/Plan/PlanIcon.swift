import SwiftUI

/// Icons a plan point or info card can use; raw values match the API.
nonisolated enum PlanIcon: String, Codable, CaseIterable, Sendable {
    case locationOn = "location_on"
    case info
    case flight
    case flightTakeoff = "flight_takeoff"
    case flightLand = "flight_land"
    case train
    case tram
    case directionsCar = "directions_car"
    case localTaxi = "local_taxi"
    case bed
    case key
    case luggage
    case confirmationNumber = "confirmation_number"
    case restaurant
    case coffee
    case bakeryDining = "bakery_dining"
    case musicNote = "music_note"
    case castle
    case park
    case storefront
    case shoppingCart = "shopping_cart"
    case photoCamera = "photo_camera"
    case howToVote = "how_to_vote"
    case savings
    case star

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = PlanIcon(rawValue: raw) ?? .locationOn
    }

    @MainActor var resource: ImageResource {
        switch self {
        case .locationOn: .locationOn
        case .info: .info
        case .flight: .flight
        case .flightTakeoff: .flightTakeoff
        case .flightLand: .flightLand
        case .train: .train
        case .tram: .tram
        case .directionsCar: .directionsCar
        case .localTaxi: .localTaxi
        case .bed: .bed
        case .key: .key
        case .luggage: .luggage
        case .confirmationNumber: .confirmationNumber
        case .restaurant: .restaurant
        case .coffee: .coffee
        case .bakeryDining: .bakeryDining
        case .musicNote: .musicNote
        case .castle: .castle
        case .park: .park
        case .storefront: .storefront
        case .shoppingCart: .shoppingCart
        case .photoCamera: .photoCamera
        case .howToVote: .howToVote
        case .savings: .savings
        case .star: .star
        }
    }

    var label: String {
        switch self {
        case .locationOn: "Miejsce"
        case .info: "Informacja"
        case .flight: "Lot"
        case .flightTakeoff: "Wylot"
        case .flightLand: "Przylot"
        case .train: "Pociąg"
        case .tram: "Tramwaj"
        case .directionsCar: "Samochód"
        case .localTaxi: "Taksówka"
        case .bed: "Nocleg"
        case .key: "Klucze"
        case .luggage: "Bagaż"
        case .confirmationNumber: "Bilet"
        case .restaurant: "Restauracja"
        case .coffee: "Kawa"
        case .bakeryDining: "Piekarnia"
        case .musicNote: "Muzyka"
        case .castle: "Zamek"
        case .park: "Park"
        case .storefront: "Sklep"
        case .shoppingCart: "Zakupy"
        case .photoCamera: "Zdjęcia"
        case .howToVote: "Głosowanie"
        case .savings: "Wspólna kasa"
        case .star: "Atrakcja"
        }
    }
}
