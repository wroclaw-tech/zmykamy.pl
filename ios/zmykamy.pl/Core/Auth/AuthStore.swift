import Observation
import UIKit

@Observable
final class AuthStore {
    enum State: Equatable {
        case restoring
        case signedOut
        case signedIn(AuthUser)
    }

    static let currentTermsVersion = "2026-10"

    private(set) var state: State = .restoring

    var user: AuthUser? {
        if case .signedIn(let user) = state { user } else { nil }
    }

    private let client: AuthClient
    private let store: SessionStore

    init(client: AuthClient = AuthClient(), store: SessionStore = SessionStore()) {
        self.client = client
        self.store = store
    }

    /// Opens with the cached session right away, then confirms it with the server.
    func restore() async {
        guard let cached = store.load() else {
            state = .signedOut
            return
        }
        state = .signedIn(cached.user)

        do {
            if let fresh = try await client.getSession(token: cached.token) {
                apply(fresh)
            } else {
                endSession()
            }
        } catch {
            // Offline or server hiccup: keep the cached session and try again next launch.
        }
    }

    func signIn(email: String, password: String) async throws(AuthError) {
        let session = try await client.signIn(SignInRequest(email: email, password: password), deviceName: UIDevice.current.name)
        apply(session)
    }

    func signUp(name: String, email: String, password: String, themePalette: String?) async throws(AuthError) {
        let session = try await client.signUp(SignUpRequest(
            name: name,
            email: email,
            password: password,
            themePalette: themePalette,
            termsVersion: Self.currentTermsVersion
        ), deviceName: UIDevice.current.name)
        apply(session)
    }

    func updateUser(_ request: UpdateUserRequest) async throws(AuthError) {
        let token = try currentToken()
        try await client.updateUser(request, token: token)
        try await refresh(token: token)
    }

    func changeEmail(to newEmail: String) async throws(AuthError) {
        let token = try currentToken()
        try await client.changeEmail(ChangeEmailRequest(newEmail: newEmail), token: token)
        try await refresh(token: token)
    }

    func changePassword(current: String, new: String, signOutOtherDevices: Bool) async throws(AuthError) {
        let request = ChangePasswordRequest(currentPassword: current, newPassword: new, revokeOtherSessions: signOutOtherDevices)
        if let session = try await client.changePassword(request, token: try currentToken()) {
            apply(session)
        }
    }

    func sessions() async throws(AuthError) -> [DeviceSession] {
        try await client.listSessions(token: try currentToken())
    }

    func isCurrent(_ session: DeviceSession) -> Bool {
        store.load()?.token.split(separator: ".").first.map(String.init) == session.token
    }

    func revoke(_ session: DeviceSession) async throws(AuthError) {
        try await client.revokeSession(RevokeSessionRequest(token: session.token), token: try currentToken())
    }

    func signOutEverywhere() async throws(AuthError) {
        try await client.revokeSessions(token: try currentToken())
        endSession()
    }

    func deleteAccount(password: String) async throws(AuthError) {
        try await client.deleteUser(DeleteUserRequest(password: password), token: try currentToken())
        endSession()
    }

    func signOut() async {
        if let token = store.load()?.token {
            try? await client.signOut(token: token)
        }
        endSession()
    }

    func currentToken() throws(AuthError) -> String {
        guard let token = store.load()?.token else { throw .unauthorized }
        return token
    }

    private func refresh(token: String) async throws(AuthError) {
        if let session = try await client.getSession(token: token) {
            apply(session)
        } else {
            endSession()
        }
    }

    private func apply(_ session: StoredSession) {
        store.save(session)
        state = .signedIn(session.user)
    }

    private func endSession() {
        store.clear()
        state = .signedOut
    }
}
