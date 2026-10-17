import Observation

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
        let session = try await client.signIn(SignInRequest(email: email, password: password))
        apply(session)
    }

    func signUp(name: String, email: String, password: String, themePalette: String?) async throws(AuthError) {
        let session = try await client.signUp(SignUpRequest(
            name: name,
            email: email,
            password: password,
            themePalette: themePalette,
            termsVersion: Self.currentTermsVersion
        ))
        apply(session)
    }

    func signOut() async {
        if let token = store.load()?.token {
            try? await client.signOut(token: token)
        }
        endSession()
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
