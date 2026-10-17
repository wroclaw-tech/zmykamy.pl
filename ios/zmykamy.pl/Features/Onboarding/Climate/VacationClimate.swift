import SwiftUI

/// Raw values match the backend `themePalette` user field.
enum VacationClimate: String, CaseIterable, Identifiable {
    case ocean
    case beach
    case cities
    case mountains
    case tropics
    case festivals

    var id: Self { self }

    var title: String {
        switch self {
        case .ocean: "Ocean"
        case .beach: "Plaża i pustynia"
        case .cities: "Miasta"
        case .mountains: "Góry i jeziora"
        case .tropics: "Tropiki"
        case .festivals: "Festiwale i noc"
        }
    }

    var subtitle: String {
        switch self {
        case .ocean: "fale, wiatr, horyzont"
        case .beach: "piasek, słońce, wydmy"
        case .cities: "dachy, uliczki, kawa"
        case .mountains: "szlaki, schroniska, cisza"
        case .tropics: "kwiaty, owoce, upał"
        case .festivals: "muzyka, światła, ekipa"
        }
    }

    var image: ImageResource {
        switch self {
        case .ocean: .onboardingWave
        case .beach: .onboardingDesert
        case .cities: .onboardingLisbon
        case .mountains: .onboardingMountains
        case .tropics: .onboardingTropics
        case .festivals: .onboardingFestivals
        }
    }

    var theme: Theme {
        switch self {
        case .ocean: .ocean
        case .beach: .slonce
        case .cities: .terakota
        case .mountains: .las
        case .tropics: .malina
        case .festivals: .sliwka
        }
    }

    var colorName: String {
        switch self {
        case .ocean: "kobalt"
        case .beach: "słońce"
        case .cities: "terakota"
        case .mountains: "las"
        case .tropics: "malina"
        case .festivals: "śliwka"
        }
    }
}
