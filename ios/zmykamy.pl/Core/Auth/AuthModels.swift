import Foundation

nonisolated struct AuthUser: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let email: String
    let image: String?
    let themePalette: String?
    let termsVersion: String?
    let termsAcceptedAt: Date?
    var emailVerified: Bool? = nil
    var firstName: String? = nil
    var lastName: String? = nil
    var phone: String? = nil
    var blikPhone: String? = nil
    var iban: String? = nil
    var language: String? = nil
    var defaultCurrency: String? = nil
    var dateFormat: String? = nil
    var weekStart: String? = nil
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

nonisolated struct UpdateUserRequest: Encodable, Equatable, Sendable {
    var name: String??
    var firstName: String??
    var lastName: String??
    var phone: String??
    var blikPhone: String??
    var iban: String??
    var themePalette: String??
    var language: String??
    var defaultCurrency: String??
    var dateFormat: String??
    var weekStart: String??

    var isEmpty: Bool {
        self == UpdateUserRequest()
    }
}

nonisolated struct ChangeEmailRequest: Encodable, Sendable {
    let newEmail: String
}

nonisolated struct ChangePasswordRequest: Encodable, Sendable {
    let currentPassword: String
    let newPassword: String
    let revokeOtherSessions: Bool
}

nonisolated struct RevokeSessionRequest: Encodable, Sendable {
    let token: String
}

nonisolated struct DeleteUserRequest: Encodable, Sendable {
    let password: String
}

nonisolated struct DeviceSession: Decodable, Identifiable, Sendable {
    let id: String
    let token: String
    let createdAt: Date
    let updatedAt: Date
    let userAgent: String?
    let deviceName: String?
    let city: String?
    let countryCode: String?
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
