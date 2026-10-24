import SwiftUI

extension ShapeStyle where Self == Color {
    static var neutralInk: Color { Color(red: 0.11, green: 0.11, blue: 0.118) }
    static var neutralInk2: Color { Color(red: 0.235, green: 0.235, blue: 0.263) }
    static var neutralGray: Color { Color(red: 0.424, green: 0.424, blue: 0.439) }
    static var neutralGray2: Color { Color(red: 0.557, green: 0.557, blue: 0.576) }
    static var neutralGray3: Color { Color(red: 0.78, green: 0.78, blue: 0.8) }
    static var neutralWhite: Color { Color(red: 1, green: 1, blue: 1) }
    static var neutralBlack: Color { Color(red: 0, green: 0, blue: 0) }

    static var alphaFill: Color { Color(red: 0.471, green: 0.471, blue: 0.502, opacity: 0.12) }
    static var alphaScrim: Color { Color(red: 0, green: 0, blue: 0, opacity: 0.28) }
    static var alphaSeparator: Color { Color(red: 0.235, green: 0.235, blue: 0.263, opacity: 0.10) }

    static var statusSuccess: Color { Color(red: 0.122, green: 0.541, blue: 0.298) }
    static var statusSuccessTint: Color { Color(red: 0.902, green: 0.969, blue: 0.933) }
    static var statusInfo: Color { Color(red: 0.039, green: 0.424, blue: 0.859) }
    static var statusInfoTint: Color { Color(red: 0.91, green: 0.945, blue: 1) }
    static var statusAI: Color { Color(red: 0.416, green: 0.294, blue: 0.878) }
    static var statusAITint: Color { Color(red: 0.945, green: 0.925, blue: 1) }
    static var statusWarning: Color { Color(red: 0.478, green: 0.325, blue: 0) }
    static var statusWarningTint: Color { Color(red: 1, green: 0.957, blue: 0.851) }
    static var statusDanger: Color { Color(red: 0.788, green: 0.263, blue: 0.102) }

    static var avatar1: Color { Color(red: 0.898, green: 0.318, blue: 0.165) }
    static var avatar2: Color { Color(red: 0.122, green: 0.373, blue: 0.82) }
    static var avatar3: Color { Color(red: 0.122, green: 0.541, blue: 0.298) }
    static var avatar4: Color { Color(red: 0.761, green: 0.255, blue: 0.478) }
    static var avatar5: Color { Color(red: 0.478, green: 0.353, blue: 0.878) }
    static var avatar6: Color { Color(red: 0.659, green: 0.455, blue: 0.047) }
}
