import SwiftUI

struct MemberAvatar: View {
    let member: TripMember
    let viewerID: String
    var size: CGFloat = 28
    var typography: Typography = .captionEmphasis
    @Environment(\.theme) private var theme

    var body: some View {
        Text(member.initial)
            .typography(typography)
            .foregroundStyle(.neutralWhite)
            .frame(width: size, height: size)
            .background(member.userId == viewerID ? theme.accent : member.avatarColor, in: .circle)
            .accessibilityHidden(true)
    }
}

extension Trip {
    func member(id: String?) -> TripMember? {
        members.first { $0.userId == id }
    }
}
