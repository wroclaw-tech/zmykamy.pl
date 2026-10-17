import Foundation
import Testing
@testable import zmykamy_pl

struct AuthModelsTests {
    @Test func decodesSignUpResponse() throws {
        let json = """
        {"token":"abc","user":{"name":"Kuba","email":"kuba@zmykamy.pl","emailVerified":false,"image":null,\
        "createdAt":"2026-10-17T19:49:16.490Z","updatedAt":"2026-10-17T19:49:16.490Z","themePalette":"mountains",\
        "termsVersion":"2026-10","termsAcceptedAt":"2026-10-17T19:49:16.490Z","id":"user-1"}}
        """
        let response = try AuthClient.decoder.decode(AuthTokenResponse.self, from: Data(json.utf8))

        #expect(response.token == "abc")
        #expect(response.user.themePalette == "mountains")
        #expect(response.user.termsAcceptedAt != nil)
    }

    @Test func decodesSessionWithoutOptionalFields() throws {
        let json = """
        {"session":{"expiresAt":"2026-10-24T19:49:16Z","token":"abc","ipAddress":null,"userAgent":null,"userId":"user-1","id":"session-1"},\
        "user":{"name":"Kuba","email":"kuba@zmykamy.pl","emailVerified":false,"image":null,"id":"user-1"}}
        """
        let response = try AuthClient.decoder.decode(SessionResponse.self, from: Data(json.utf8))

        #expect(response.session.id == "session-1")
        #expect(response.user.themePalette == nil)
        #expect(response.user.termsAcceptedAt == nil)
    }

    @Test func decodesMissingSessionAsNil() throws {
        let response = try AuthClient.decoder.decode(SessionResponse?.self, from: Data("null".utf8))
        #expect(response == nil)
    }

    @Test(arguments: [
        (401, "INVALID_EMAIL_OR_PASSWORD" as String?, AuthError.invalidCredentials),
        (422, "USER_ALREADY_EXISTS_USE_ANOTHER_EMAIL", .userAlreadyExists),
        (400, "PASSWORD_TOO_SHORT", .passwordTooShort),
        (401, nil, .unauthorized),
        (500, nil, .server(status: 500, code: nil)),
    ])
    func mapsErrorCodes(status: Int, code: String?, expected: AuthError) {
        let error = AuthError(status: status, response: AuthErrorResponse(code: code, message: nil))
        #expect(error == expected)
    }
}
