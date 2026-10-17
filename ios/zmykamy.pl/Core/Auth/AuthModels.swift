import Foundation

nonisolated struct AuthUser: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let email: String
    let image: String?
    let themePalette: String?
    let termsVersion: String?
    let termsAcceptedAt: Date?
}

nonisolated struct AuthSessionInfo: Codable, Equatable, Sendable {
    let id: String
    let expiresAt: Date
}

nonisolated struct SessionResponse: Decodable, Sendable {
    let session: AuthSessionInfo
    let user: AuthUser
}

nonisolated struct AuthTokenResponse: Decodable, Sendable {
    let token: String?
    let user: AuthUser
}

nonisolated struct SignUpRequest: Encodable, Sendable {
    let name: String
    let email: String
    let password: String
    let themePalette: String?
    let termsVersion: String
}

nonisolated struct SignInRequest: Encodable, Sendable {
    let email: String
    let password: String
}

/// Persisted in the keychain so the app can open signed in without a network round trip.
nonisolated struct StoredSession: Codable, Sendable {
    var token: String
    var user: AuthUser
}

nonisolated struct AuthErrorResponse: Decodable, Sendable {
    let code: String?
    let message: String?
}
