import CryptoKit
import Foundation

nonisolated struct GoogleOAuth: Equatable, Sendable {
    static let scope = "https://www.googleapis.com/auth/photospicker.mediaitems.readonly"
    static let authorizationURL = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!

    let clientID: String

    static var configured: GoogleOAuth? {
        let value = (Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, value.hasSuffix(".apps.googleusercontent.com") else { return nil }
        return GoogleOAuth(clientID: value)
    }

    var callbackScheme: String {
        clientID.split(separator: ".").reversed().joined(separator: ".")
    }

    var redirectURI: String {
        "\(callbackScheme):/oauth2redirect"
    }

    func authorizationURL(challenge: String, state: String) -> URL {
        var components = URLComponents(url: Self.authorizationURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.scope),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ]
        return components.url!
    }

    func tokenForm(code: String, verifier: String) -> Data {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "code_verifier", value: verifier),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
        ]
        let encoded = components.percentEncodedQuery ?? ""
        return Data(encoded.replacingOccurrences(of: "+", with: "%2B").utf8)
    }

    static func code(from callback: URL, state: String) throws(GooglePhotosError) -> String {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let value = { (name: String) in items.first { $0.name == name }?.value }
        if value("error") == "access_denied" { throw .cancelled }
        guard value("state") == state, let code = value("code"), !code.isEmpty else { throw .signInFailed }
        return code
    }
}

nonisolated struct PKCE: Sendable {
    let verifier: String

    static func random() -> PKCE {
        PKCE(verifier: randomString(bytes: 32))
    }

    static func randomString(bytes count: Int) -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<count).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return Data(bytes).base64URLEncoded
    }

    var challenge: String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
    }
}

private extension Data {
    nonisolated var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

nonisolated struct GoogleAccessToken: Equatable, Sendable {
    let value: String
    let expiresAt: Date

    func isUsable(at now: Date) -> Bool {
        expiresAt.timeIntervalSince(now) > 10 * 60
    }
}

nonisolated struct GoogleTokenResponse: Decodable, Sendable {
    let accessToken: String
    let expiresIn: Int

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }

    func token(receivedAt now: Date) -> GoogleAccessToken {
        GoogleAccessToken(value: accessToken, expiresAt: now.addingTimeInterval(TimeInterval(expiresIn)))
    }
}

nonisolated enum GoogleDuration {
    static func seconds(from text: String?) -> Double? {
        guard let text, text.hasSuffix("s") else { return nil }
        return Double(text.dropLast())
    }
}

nonisolated struct PickerSession: Decodable, Equatable, Sendable {
    struct PollingConfig: Decodable, Equatable, Sendable {
        let pollInterval: String?
        let timeoutIn: String?
    }

    let id: String
    let pickerUri: URL
    let mediaItemsSet: Bool?
    let pollingConfig: PollingConfig?

    var pickerURL: URL {
        pickerUri.appending(path: "autoclose")
    }
}

nonisolated enum PickerPoll: Equatable, Sendable {
    case ready
    case wait(seconds: Double)
    case timedOut

    static let defaultInterval: Double = 5
    static let minimumInterval: Double = 1

    init(_ session: PickerSession) {
        if session.mediaItemsSet == true {
            self = .ready
            return
        }
        if let timeout = GoogleDuration.seconds(from: session.pollingConfig?.timeoutIn), timeout <= 0 {
            self = .timedOut
            return
        }
        let interval = GoogleDuration.seconds(from: session.pollingConfig?.pollInterval) ?? Self.defaultInterval
        self = .wait(seconds: max(interval, Self.minimumInterval))
    }
}

nonisolated struct PickedMediaItem: Decodable, Equatable, Sendable {
    struct MediaFile: Decodable, Equatable, Sendable {
        let baseUrl: String
        let mimeType: String?
        let mediaFileMetadata: Metadata?
    }

    struct Metadata: Decodable, Equatable, Sendable {
        let videoMetadata: VideoMetadata?
    }

    struct VideoMetadata: Decodable, Equatable, Sendable {
        let processingStatus: String?
    }

    static let photoSize = "=w2048-h2048"
    static let videoDownload = "=dv"

    let id: String
    let createTime: String?
    let type: String?
    let mediaFile: MediaFile

    var kind: MediaKind? {
        switch type {
        case "PHOTO": .photo
        case "VIDEO": .video
        default:
            if mediaFile.mimeType?.hasPrefix("image/") == true { .photo }
            else if mediaFile.mimeType?.hasPrefix("video/") == true { .video }
            else { nil }
        }
    }

    var downloadURL: URL? {
        switch kind {
        case .photo:
            return URL(string: mediaFile.baseUrl + Self.photoSize)
        case .video:
            let status = mediaFile.mediaFileMetadata?.videoMetadata?.processingStatus
            guard status == nil || status == "READY" else { return nil }
            return URL(string: mediaFile.baseUrl + Self.videoDownload)
        case nil:
            return nil
        }
    }

    var createdAt: Date? {
        createTime.flatMap(ISODateTime.date(from:))
    }
}

nonisolated struct PickedMediaPage: Decodable, Sendable {
    let mediaItems: [PickedMediaItem]?
    let nextPageToken: String?
}

nonisolated struct GooglePhotosImportResult: Equatable, Sendable {
    var imported = 0
    var skipped = 0
    var failed = 0

    var summary: String {
        var parts: [String] = []
        if imported > 0 || (skipped == 0 && failed == 0) {
            parts.append("Dodano \(imported) \(PolishPlural.form(imported, one: "element", few: "elementy", many: "elementów")) do galerii.")
        }
        if skipped > 0 {
            parts.append("Już w galerii: \(skipped).")
        }
        if failed > 0 {
            parts.append("Nie udało się pobrać: \(failed).")
        }
        return parts.joined(separator: " ")
    }
}

nonisolated enum GooglePhotosError: LocalizedError, Equatable, Sendable {
    case cancelled
    case signInFailed
    case unauthorized
    case timedOut
    case network
    case server(status: Int)

    var errorDescription: String? {
        switch self {
        case .cancelled: nil
        case .signInFailed: "Nie udało się zalogować do Google. Spróbuj ponownie."
        case .unauthorized: "Dostęp do Google Photos wygasł. Zaloguj się ponownie i uruchom import jeszcze raz."
        case .timedOut: "Minął czas na wybór zdjęć. Spróbuj ponownie."
        case .network: "Brak połączenia z Google Photos. Spróbuj ponownie."
        case .server: "Google Photos nie odpowiada. Spróbuj ponownie za chwilę."
        }
    }
}
