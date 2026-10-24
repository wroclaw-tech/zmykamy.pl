import Foundation

/// Minimal client for the Better Auth endpoints the app uses, authenticated with the `bearer` plugin.
nonisolated final class AuthClient: Sendable {
    static let minPasswordLength = 8

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = APIConfiguration.authBaseURL) {
        self.baseURL = baseURL
        // Sending cookies would make Better Auth enforce an Origin check that a native app can't satisfy.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        self.session = URLSession(configuration: configuration)
    }

    func signUp(_ request: SignUpRequest, deviceName: String) async throws(AuthError) -> StoredSession {
        let (body, response) = try await send("sign-up/email", method: "POST", body: request, deviceName: deviceName)
        return try storedSession(from: body, response: response)
    }

    func signIn(_ request: SignInRequest, deviceName: String) async throws(AuthError) -> StoredSession {
        let (body, response) = try await send("sign-in/email", method: "POST", body: request, deviceName: deviceName)
        return try storedSession(from: body, response: response)
    }

    /// Returns `nil` when the token no longer maps to a valid session.
    func getSession(token: String) async throws(AuthError) -> StoredSession? {
        let body: Data
        let response: HTTPURLResponse
        do {
            (body, response) = try await send("get-session", method: "GET", token: token)
        } catch .unauthorized {
            return nil
        }
        guard let session = try decode(SessionResponse?.self, from: body) else { return nil }
        return StoredSession(token: rotatedToken(in: response) ?? token, user: session.user)
    }

    func signOut(token: String) async throws(AuthError) {
        _ = try await send("sign-out", method: "POST", body: [String: String](), token: token)
    }

    func updateUser(_ request: UpdateUserRequest, token: String) async throws(AuthError) {
        _ = try await send("update-user", method: "POST", body: request, token: token)
    }

    func changeEmail(_ request: ChangeEmailRequest, token: String) async throws(AuthError) {
        _ = try await send("change-email", method: "POST", body: request, token: token)
    }

    func changePassword(_ request: ChangePasswordRequest, token: String) async throws(AuthError) -> StoredSession? {
        let (body, response) = try await send("change-password", method: "POST", body: request, token: token)
        let payload = try decode(AuthTokenResponse.self, from: body)
        guard let newToken = rotatedToken(in: response) ?? payload.token else { return nil }
        return StoredSession(token: newToken, user: payload.user)
    }

    func listSessions(token: String) async throws(AuthError) -> [DeviceSession] {
        let (body, _) = try await send("list-sessions", method: "GET", token: token)
        return try decode([DeviceSession].self, from: body)
    }

    func revokeSession(_ request: RevokeSessionRequest, token: String) async throws(AuthError) {
        _ = try await send("revoke-session", method: "POST", body: request, token: token)
    }

    func revokeSessions(token: String) async throws(AuthError) {
        _ = try await send("revoke-sessions", method: "POST", body: [String: String](), token: token)
    }

    func deleteUser(_ request: DeleteUserRequest, token: String) async throws(AuthError) {
        _ = try await send("delete-user", method: "POST", body: request, token: token)
    }

    private func storedSession(from body: Data, response: HTTPURLResponse) throws(AuthError) -> StoredSession {
        let payload = try decode(AuthTokenResponse.self, from: body)
        guard let token = rotatedToken(in: response) ?? payload.token else {
            throw .server(status: response.statusCode, code: "MISSING_TOKEN")
        }
        return StoredSession(token: token, user: payload.user)
    }

    private func rotatedToken(in response: HTTPURLResponse) -> String? {
        guard let token = response.value(forHTTPHeaderField: "set-auth-token"), !token.isEmpty else { return nil }
        return token
    }

    private func send(
        _ path: String,
        method: String,
        body: (some Encodable & Sendable)? = String?.none,
        token: String? = nil,
        deviceName: String? = nil
    ) async throws(AuthError) -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let deviceName {
            request.setValue(deviceName, forHTTPHeaderField: "X-Device-Name")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw .server(status: 0, code: "ENCODING_FAILED")
            }
        }

        let data: Data
        let urlResponse: URLResponse
        do {
            (data, urlResponse) = try await session.data(for: request)
        } catch {
            throw .network
        }
        guard let response = urlResponse as? HTTPURLResponse else { throw .network }
        guard (200..<300).contains(response.statusCode) else {
            throw AuthError(status: response.statusCode, response: try? Self.decoder.decode(AuthErrorResponse.self, from: data))
        }
        return (data, response)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws(AuthError) -> T {
        do {
            return try Self.decoder.decode(type, from: data)
        } catch {
            throw .server(status: 200, code: "DECODING_FAILED")
        }
    }

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = try? Date(string, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
                return date
            }
            if let date = try? Date(string, strategy: .iso8601) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
        return decoder
    }()
}
