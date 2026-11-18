import Foundation
@testable import zmykamy_pl

/// An in-memory stand-in for the zmykamy.pl backend.
///
/// Only the network is faked: requests go through the app's real `APIClient`/`AuthClient`,
/// and stores built from `signedIn()` use a real (per-test) keychain entry. Each backend
/// gets its own host, so tests can run in parallel without seeing each other's traffic.
final class FakeBackend: @unchecked Sendable {
    struct Request {
        let method: String
        let path: String
        let headers: [String: String]
        let body: Data?
        var query: [String: String] = [:]

        func header(_ name: String) -> String? {
            headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
        }

        /// The JSON body as a dictionary; JSON `null` values show up as `NSNull`.
        var json: [String: Any]? {
            body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        }
    }

    fileprivate enum Reply {
        case response(status: Int, headers: [String: String], body: Data)
        case offline
    }

    let baseURL: URL
    let keychain: SessionStore

    private let lock = NSLock()
    private var routes: [String: Reply] = [:]
    private var isOffline = false
    private var recorded: [Request] = []

    init() {
        let id = UUID().uuidString.lowercased()
        baseURL = URL(string: "https://\(id).backend.test")!
        keychain = SessionStore(service: "pl.zmykamy.tests.\(id)")
        FakeBackendProtocol.register(self, host: baseURL.host()!)
    }

    deinit {
        keychain.clear()
        FakeBackendProtocol.unregister(host: baseURL.host()!)
    }

    // MARK: Stubbing

    /// Responds to `method path` (path without a leading slash, e.g. `trips/t1/polls`).
    func on(_ method: String, _ path: String, status: Int = 200, headers: [String: String] = [:], json: String = "{}") {
        set(.response(status: status, headers: headers, body: Data(json.utf8)), for: method, path)
    }

    /// Responds with the API encoding of `value` (dates as ISO 8601, like the backend).
    func on(_ method: String, _ path: String, status: Int = 200, headers: [String: String] = [:], returning value: some Encodable) {
        set(.response(status: status, headers: headers, body: try! Self.encoder.encode(value)), for: method, path)
    }

    /// Makes `method path` fail as if the device had no connection.
    func offline(_ method: String, _ path: String) {
        set(.offline, for: method, path)
    }

    /// Makes every request fail as if the device had no connection.
    func goOffline() {
        lock.withLock { isOffline = true }
    }

    var requests: [Request] {
        lock.withLock { recorded }
    }

    func requests(_ method: String, _ path: String) -> [Request] {
        requests.filter { $0.method == method && $0.path == path }
    }

    // MARK: Clients

    var urlSessionConfiguration: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FakeBackendProtocol.self]
        return configuration
    }

    var apiClient: APIClient {
        APIClient(baseURL: baseURL, session: URLSession(configuration: urlSessionConfiguration))
    }

    var authClient: AuthClient {
        AuthClient(baseURL: baseURL.appending(path: "auth"), configuration: urlSessionConfiguration)
    }

    /// An auth store backed by this backend and a keychain entry private to this test.
    @MainActor
    func authStore() -> AuthStore {
        AuthStore(client: authClient, store: keychain)
    }

    /// An auth store whose keychain already holds a session, as after a previous launch.
    @MainActor
    func signedIn(as user: AuthUser = .fixture(), token: String = "token-1") -> AuthStore {
        keychain.save(StoredSession(token: token, user: user))
        return authStore()
    }

    @MainActor
    func api(_ auth: AuthStore) -> AuthorizedAPI {
        AuthorizedAPI(auth: auth, client: apiClient)
    }

    // MARK: Handling

    fileprivate func handle(_ request: URLRequest) -> (Request, Reply) {
        let url = request.url!
        let path = url.path(percentEncoded: false).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let method = request.httpMethod ?? "GET"
        let recordedRequest = Request(
            method: method,
            path: path,
            headers: request.allHTTPHeaderFields ?? [:],
            body: request.httpBody ?? request.httpBodyStream.map(Self.read),
            query: Dictionary((URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { _, last in last })
        )
        return lock.withLock {
            recorded.append(recordedRequest)
            if isOffline { return (recordedRequest, .offline) }
            let reply = routes["\(method) \(path)"]
                ?? .response(status: 404, headers: [:], body: Data(#"{"error":{"code":"NOT_STUBBED"}}"#.utf8))
            return (recordedRequest, reply)
        }
    }

    private func set(_ reply: Reply, for method: String, _ path: String) {
        lock.withLock { routes["\(method) \(path)"] = reply }
    }

    private static func read(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

/// Routes requests to the `FakeBackend` that owns the request's host.
private final class FakeBackendProtocol: URLProtocol {
    private struct WeakBackend {
        weak var backend: FakeBackend?
    }

    private nonisolated(unsafe) static var backends: [String: WeakBackend] = [:]
    private static let lock = NSLock()

    static func register(_ backend: FakeBackend, host: String) {
        lock.withLock { backends[host] = WeakBackend(backend: backend) }
    }

    static func unregister(host: String) {
        lock.withLock { _ = backends.removeValue(forKey: host) }
    }

    private static func backend(for request: URLRequest) -> FakeBackend? {
        guard let host = request.url?.host() else { return nil }
        return lock.withLock { backends[host]?.backend }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        backend(for: request) != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let backend = Self.backend(for: request) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        switch backend.handle(request).1 {
        case .offline:
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
        case let .response(status: status, headers: headers, body: body):
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
