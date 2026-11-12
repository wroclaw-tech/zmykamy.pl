import Foundation
import Observation

struct PendingInvite: Identifiable, Equatable {
    let code: String

    var id: String { code }
}

/// Holds an invite opened from a link until the user is signed in and can act on it.
@Observable
final class InviteLinkRouter {
    var pending: PendingInvite?

    func open(_ url: URL) {
        guard let slug = InviteLink.slug(from: url) else { return }
        open(code: slug)
    }

    func open(code: String) {
        pending = PendingInvite(code: code)
    }
}
