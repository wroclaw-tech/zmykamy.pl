import Foundation

/// Client for the app's own REST endpoints, authenticated with the session bearer token.
nonisolated final class APIClient: Sendable {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = APIConfiguration.baseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func send<Response: Decodable>(
        _ method: String,
        _ path: String,
        body: (some Encodable & Sendable)? = String?.none,
        token: String
    ) async throws(APIError) -> Response {
        let data = try await perform(method, path, body: body, token: token)
        do {
            return try Self.decoder.decode(Response.self, from: data)
        } catch {
            throw .server(status: 200, code: "DECODING_FAILED")
        }
    }

    func send(
        _ method: String,
        _ path: String,
        body: (some Encodable & Sendable)? = String?.none,
        token: String
    ) async throws(APIError) {
        _ = try await perform(method, path, body: body, token: token)
    }

    /// Uploads straight to storage through a presigned URL, so no bearer token is sent.
    func upload(_ data: Data, to url: URL, contentType: String) async throws(APIError) {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        try await validate(request, upload: data)
    }

    private func perform(
        _ method: String,
        _ path: String,
        body: (some Encodable & Sendable)?,
        token: String
    ) async throws(APIError) -> Data {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw .server(status: 0, code: "ENCODING_FAILED")
            }
        }
        return try await validate(request)
    }

    @discardableResult
    private func validate(_ request: URLRequest, upload: Data? = nil) async throws(APIError) -> Data {
        let data: Data
        let urlResponse: URLResponse
        do {
            if let upload {
                (data, urlResponse) = try await session.upload(for: request, from: upload)
            } else {
                (data, urlResponse) = try await session.data(for: request)
            }
        } catch {
            throw .network
        }
        guard let response = urlResponse as? HTTPURLResponse else { throw .network }
        guard (200..<300).contains(response.statusCode) else {
            throw APIError(status: response.statusCode, response: try? Self.decoder.decode(APIErrorResponse.self, from: data))
        }
        return data
    }

    static let decoder = JSONDecoder()
}
