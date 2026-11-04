import Foundation

nonisolated enum APIConfiguration {
    /// Debug builds default to the local backend; enable `ZMYKAMY_API_URL` in the scheme to use production.
    static let baseURL: URL = {
        if let override = ProcessInfo.processInfo.environment["ZMYKAMY_API_URL"],
           let url = URL(string: override) {
            return url
        }
        #if DEBUG
        return URL(string: "http://localhost:3000")!
        #else
        return URL(string: "https://api.zmykamy.pl")!
        #endif
    }()

    static let authBaseURL = baseURL.appending(path: "auth")
}
