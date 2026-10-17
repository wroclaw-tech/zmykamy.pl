import SwiftUI

struct Typography {
    let size: CGFloat
    let weight: Font.Weight
    var tracking: CGFloat = 0

    static let displayAmount = Typography(size: 60, weight: .heavy, tracking: -2.5)
    static let displayLogo = Typography(size: 46, weight: .heavy, tracking: -2)
    static let displayCountdown = Typography(size: 42, weight: .heavy, tracking: -1.4)
    static let titleLarge = Typography(size: 34, weight: .bold, tracking: -0.6)
    static let title1 = Typography(size: 26, weight: .bold, tracking: -0.6)
    static let title2 = Typography(size: 22, weight: .bold, tracking: -0.4)
    static let title3 = Typography(size: 20, weight: .bold, tracking: -0.3)
    static let headline = Typography(size: 17, weight: .semibold, tracking: -0.3)
    static let bodyLarge = Typography(size: 17, weight: .regular)
    static let bodyRegular = Typography(size: 16, weight: .regular)
    static let bodyEmphasis = Typography(size: 16, weight: .semibold)
    static let calloutRegular = Typography(size: 15, weight: .regular)
    static let calloutEmphasis = Typography(size: 15, weight: .semibold)
    static let subheadRegular = Typography(size: 14, weight: .regular)
    static let subheadEmphasis = Typography(size: 14, weight: .semibold)
    static let footnote = Typography(size: 13, weight: .regular)
    static let sectionLabel = Typography(size: 13, weight: .semibold, tracking: 0.3)
    static let captionRegular = Typography(size: 12, weight: .regular)
    static let captionEmphasis = Typography(size: 12, weight: .semibold)
    static let captionBadge = Typography(size: 11, weight: .bold)
    static let tabLabel = Typography(size: 10, weight: .semibold)
    static let micro = Typography(size: 9, weight: .bold)
}

extension View {
    func typography(_ typography: Typography) -> some View {
        font(.system(size: typography.size, weight: typography.weight))
            .tracking(typography.tracking)
    }
}
