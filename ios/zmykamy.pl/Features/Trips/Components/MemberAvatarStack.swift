import SwiftUI

extension TripMember {
    var initial: String {
        String(name.prefix(1)).uppercased()
    }

    var avatarColor: Color {
        AvatarColor.color(for: userId)
    }
}

enum AvatarColor {
    static func color(for userID: String) -> Color {
        let colors: [Color] = [.avatar1, .avatar2, .avatar3, .avatar4, .avatar5, .avatar6]
        let seed = userID.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return colors[seed % colors.count]
    }
}

struct PersonAvatar: View {
    let userID: String
    let name: String
    var isViewer = false
    var size: CGFloat = 32
    var borderColor: Color?
    @Environment(\.theme) private var theme

    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(.neutralWhite)
            .frame(width: size, height: size)
            .background(isViewer ? theme.accent : AvatarColor.color(for: userID), in: .circle)
            .overlay {
                if let borderColor {
                    Circle().strokeBorder(borderColor, lineWidth: 2)
                }
            }
            .accessibilityHidden(true)
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
