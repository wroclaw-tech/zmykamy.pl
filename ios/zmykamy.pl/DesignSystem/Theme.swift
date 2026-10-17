import SwiftUI

struct Theme: Identifiable, Hashable {
    let id: String
    let name: String
    let accent: Color
    let accentStrong: Color
    let accentTint: Color
    let background: Color

    static let ocean = Theme(
        id: "ocean",
        name: "Ocean",
        accent: Color(red: 0.122, green: 0.373, blue: 0.82),
        accentStrong: Color(red: 0.102, green: 0.302, blue: 0.659),
        accentTint: Color(red: 0.902, green: 0.933, blue: 0.988),
        background: Color(red: 0.961, green: 0.949, blue: 0.922)
    )
    static let slonce = Theme(
        id: "slonce",
        name: "Słońce",
        accent: Color(red: 0.902, green: 0.706, blue: 0),
        accentStrong: Color(red: 0.702, green: 0.353, blue: 0),
        accentTint: Color(red: 0.969, green: 0.961, blue: 0.737),
        background: Color(red: 0.98, green: 0.976, blue: 0.933)
    )
    static let terakota = Theme(
        id: "terakota",
        name: "Terakota",
        accent: Color(red: 0.898, green: 0.318, blue: 0.165),
        accentStrong: Color(red: 0.788, green: 0.263, blue: 0.102),
        accentTint: Color(red: 0.992, green: 0.929, blue: 0.906),
        background: Color(red: 0.949, green: 0.949, blue: 0.969)
    )
    static let las = Theme(
        id: "las",
        name: "Las",
        accent: Color(red: 0.278, green: 0.502, blue: 0.18),
        accentStrong: Color(red: 0.2, green: 0.369, blue: 0.125),
        accentTint: Color(red: 0.902, green: 0.941, blue: 0.875),
        background: Color(red: 0.953, green: 0.957, blue: 0.933)
    )
    static let malina = Theme(
        id: "malina",
        name: "Malina",
        accent: Color(red: 0.839, green: 0.2, blue: 0.424),
        accentStrong: Color(red: 0.69, green: 0.141, blue: 0.341),
        accentTint: Color(red: 0.988, green: 0.906, blue: 0.937),
        background: Color(red: 0.98, green: 0.961, blue: 0.949)
    )
    static let sliwka = Theme(
        id: "sliwka",
        name: "Śliwka",
        accent: Color(red: 0.416, green: 0.247, blue: 0.82),
        accentStrong: Color(red: 0.333, green: 0.192, blue: 0.69),
        accentTint: Color(red: 0.933, green: 0.91, blue: 0.988),
        background: Color(red: 0.965, green: 0.953, blue: 0.98)
    )

    static let all: [Theme] = [.ocean, .slonce, .terakota, .las, .malina, .sliwka]
}

extension EnvironmentValues {
    @Entry var theme: Theme = .ocean
}
