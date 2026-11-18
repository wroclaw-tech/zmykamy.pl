import Foundation

nonisolated final class GooglePhotosClient: Sendable {
    private let pickerURL: URL
    private let tokenURL: URL
    private let revokeURL: URL
    private let session: URLSession

    init(
        pickerURL: URL = URL(string: "https://photospicker.googleapis.com/v1")!,
        tokenURL: URL = URL(string: "https://oauth2.googleapis.com/token")!,
        revokeURL: URL = URL(string: "https://oauth2.googleapis.com/revoke")!,
        session: URLSession = .shared
    ) {
        self.pickerURL = pickerURL
        self.tokenURL = tokenURL
        self.revokeURL = revokeURL
        self.session = session
    }

    func exchange(code: String, verifier: String, oauth: GoogleOAuth, now: Date) async throws(GooglePhotosError) -> GoogleAccessToken {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = oauth.tokenForm(code: code, verifier: verifier)
        let response: GoogleTokenResponse
        do throws(GooglePhotosError) {
            response = try await decode(perform(request))
        } catch .unauthorized, .server(status: 400) {
            throw .signInFailed
        }
        return response.token(receivedAt: now)
    }

    func revoke(_ token: GoogleAccessToken) async {
        var request = URLRequest(url: revokeURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "token", value: token.value)]
        request.httpBody = Data((components.percentEncodedQuery ?? "").utf8)
        _ = try? await perform(request)
    }

    func createSession(token: GoogleAccessToken) async throws(GooglePhotosError) -> PickerSession {
        var request = authorized(pickerURL.appending(path: "sessions"), token: token)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        return try await decode(perform(request))
    }

    func session(_ id: String, token: GoogleAccessToken) async throws(GooglePhotosError) -> PickerSession {
        try await decode(perform(authorized(pickerURL.appending(path: "sessions/\(id)"), token: token)))
    }

    func deleteSession(_ id: String, token: GoogleAccessToken) async {
        var request = authorized(pickerURL.appending(path: "sessions/\(id)"), token: token)
        request.httpMethod = "DELETE"
        _ = try? await perform(request)
    }

    func mediaItems(in sessionID: String, token: GoogleAccessToken) async throws(GooglePhotosError) -> [PickedMediaItem] {
        var items: [PickedMediaItem] = []
        var pageToken: String?
        repeat {
            var components = URLComponents(url: pickerURL.appending(path: "mediaItems"), resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "sessionId", value: sessionID),
                URLQueryItem(name: "pageSize", value: "100"),
            ] + (pageToken.map { [URLQueryItem(name: "pageToken", value: $0)] } ?? [])
            let page: PickedMediaPage = try await decode(perform(authorized(components.url!, token: token)))
            items += page.mediaItems ?? []
            pageToken = page.nextPageToken.flatMap { $0.isEmpty ? nil : $0 }
        } while pageToken != nil
        return items
    }

    func download(_ url: URL, fileExtension: String, token: GoogleAccessToken) async throws(GooglePhotosError) -> URL {
        let location: URL
        let urlResponse: URLResponse
        do {
            (location, urlResponse) = try await session.download(for: authorized(url, token: token))
        } catch {
            throw .network
        }
        try Self.validate(urlResponse)
        let destination = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).\(fileExtension)")
        do {
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            throw .network
        }
        return destination
    }

    private func authorized(_ url: URL, token: GoogleAccessToken) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token.value)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func perform(_ request: URLRequest) async throws(GooglePhotosError) -> Data {
        let data: Data
        let urlResponse: URLResponse
        do {
            (data, urlResponse) = try await session.data(for: request)
        } catch {
            throw .network
        }
        try Self.validate(urlResponse)
        return data
    }

    private func decode<Response: Decodable>(_ data: Data) throws(GooglePhotosError) -> Response {
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw .server(status: 200)
        }
    }

    private static func validate(_ urlResponse: URLResponse) throws(GooglePhotosError) {
        guard let response = urlResponse as? HTTPURLResponse else { throw .network }
        switch response.statusCode {
        case 200..<300: return
        case 401: throw .unauthorized
        default: throw .server(status: response.statusCode)
        }
    }
}
