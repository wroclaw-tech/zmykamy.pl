import Foundation

nonisolated enum UnitCategory: String, CaseIterable, Identifiable {
    case length = "Długość", weight = "Waga", temperature = "Temp.", sizes = "Rozmiary"
    var id: Self { self }

    var units: [ConversionUnit] {
        switch self {
        case .length: [.kilometers, .miles, .meters, .feet, .centimeters, .inches]
        case .weight: [.kilograms, .pounds, .grams, .ounces]
        case .temperature: [.celsius, .fahrenheit, .kelvin]
        case .sizes: [.euShoes, .ukShoes, .usMenShoes, .usWomenShoes]
        }
    }
    var subtitle: String {
        switch self {
        case .length: "Długość trasy"
        case .weight: "Masa bagażu"
        case .temperature: "Temperatura"
        case .sizes: "Buty dla dorosłych · orientacyjnie"
        }
    }
}

nonisolated enum ConversionUnit: String, CaseIterable, Identifiable {
    case kilometers = "Kilometry", miles = "Mile", meters = "Metry", feet = "Stopy", centimeters = "Centymetry", inches = "Cale"
    case kilograms = "Kilogramy", pounds = "Funty", grams = "Gramy", ounces = "Uncje"
    case celsius = "Celsjusza", fahrenheit = "Fahrenheita", kelvin = "Kelwiny"
    case euShoes = "EU", ukShoes = "UK", usMenShoes = "US męskie", usWomenShoes = "US damskie"
    var id: Self { self }
    var symbol: String {
        switch self {
        case .kilometers: "km"
        case .miles: "mi"
        case .meters: "m"
        case .feet: "ft"
        case .centimeters: "cm"
        case .inches: "in"
        case .kilograms: "kg"
        case .pounds: "lb"
        case .grams: "g"
        case .ounces: "oz"
        case .celsius: "°C"
        case .fahrenheit: "°F"
        case .kelvin: "K"
        case .euShoes: "EU"
        case .ukShoes: "UK"
        case .usMenShoes: "US ♂"
        case .usWomenShoes: "US ♀"
        }
    }
    private var factor: Double {
        switch self {
        case .kilometers: 1000
        case .miles: 1609.344
        case .meters, .kilograms: 1
        case .feet: 0.3048
        case .centimeters: 0.01
        case .inches: 0.0254
        case .pounds: 0.45359237
        case .grams: 0.001
        case .ounces: 0.028349523125
        default: 1
        }
    }
    private var shoeOffset: Double {
        switch self {
        case .euShoes: 0
        case .ukShoes: 34
        case .usMenShoes: 33
        case .usWomenShoes: 31.5
        default: 0
        }
    }
    var category: UnitCategory {
        UnitCategory.allCases.first { $0.units.contains(self) }!
    }
    func convert(_ value: Double, to target: Self) -> Double? {
        guard value.isFinite, category == target.category else { return nil }
        let result: Double
        switch category {
        case .temperature:
            let celsius = self == .fahrenheit ? (value - 32) * 5 / 9 : self == .kelvin ? value - 273.15 : value
            guard celsius >= -273.15 else { return nil }
            result = target == .fahrenheit ? celsius * 9 / 5 + 32 : target == .kelvin ? celsius + 273.15 : celsius
        case .sizes:
            guard value > 0 else { return nil }
            result = value + shoeOffset - target.shoeOffset
            guard result > 0 else { return nil }
        default:
            guard value >= 0 else { return nil }
            result = value * factor / target.factor
        }
        return result.isFinite ? result : nil
    }
}
