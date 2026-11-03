import Foundation

/// Runs requests with the current session token and signs out when the session is no longer valid.
final class AuthorizedAPI {
    let client: APIClient
    private let auth: AuthStore

    init(auth: AuthStore, client: APIClient = APIClient()) {
        self.auth = auth
        self.client = client
    }

    func call<Response>(
        _ request: (APIClient, String) async throws(APIError) -> Response
    ) async throws(APIError) -> Response {
        do throws(APIError) {
            let token: String
            do {
                token = try auth.currentToken()
            } catch {
                throw APIError.unauthorized
            }
            return try await request(client, token)
        } catch .unauthorized {
            await auth.signOut()
            throw .unauthorized
        }
    }
}
