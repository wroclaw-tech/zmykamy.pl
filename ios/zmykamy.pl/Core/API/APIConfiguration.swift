import Foundation

nonisolated enum APIConfiguration {
    /// Set `ZMYKAMY_API_URL` in the scheme's environment to point at a local backend.
    static let baseURL: URL = {
        if let override = ProcessInfo.processInfo.environment["ZMYKAMY_API_URL"],
           let url = URL(string: override) {
            return url
        }
        return URL(string: "https://api-zmykamy.b.solvro.pl")!
    }()

    static let authBaseURL = baseURL.appending(path: "auth")
}
