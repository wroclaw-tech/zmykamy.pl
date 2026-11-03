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
        let components = url.pathComponents
        guard components.count == 3, components[1] == "j" else { return }
        pending = PendingInvite(code: components[2])
    }
}
