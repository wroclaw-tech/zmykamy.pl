import SwiftUI

extension TripMember {
    var initial: String {
        String(name.prefix(1)).uppercased()
    }

    /// Stable across launches, unlike `hashValue`, so a member keeps the same color everywhere.
    var avatarColor: Color {
        let colors: [Color] = [.avatar1, .avatar2, .avatar3, .avatar4, .avatar5, .avatar6]
        let seed = userId.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return colors[seed % colors.count]
    }
}

/// Members as overlapping initials; the viewer is drawn in their own theme accent.
struct MemberAvatarStack: View {
    let members: [TripMember]
    let viewerID: String
    var size: CGFloat = 26
    var borderColor: Color = .neutralWhite
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: -size * 0.27) {
            ForEach(members) { member in
                Text(member.initial)
                    .typography(.captionBadge)
                    .foregroundStyle(.neutralWhite)
                    .frame(width: size, height: size)
                    .background(member.userId == viewerID ? theme.accent : member.avatarColor, in: .circle)
                    .overlay { Circle().strokeBorder(borderColor, lineWidth: 2) }
            }
        }
        .accessibilityHidden(true)
    }
}
