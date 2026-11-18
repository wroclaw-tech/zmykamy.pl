import Foundation
import Testing
import UIKit
@testable import zmykamy_pl

struct GooglePhotosModelsTests {
    let oauth = GoogleOAuth(clientID: "123-abc.apps.googleusercontent.com")

    @Test func derivesThePKCEChallengeLikeRFC7636() {
        let pkce = PKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")

        #expect(pkce.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test func redirectsToTheReversedClientID() throws {
        let url = oauth.authorizationURL(challenge: "challenge", state: "state-1")
        let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let value = { (name: String) in query.first { $0.name == name }?.value }

        #expect(oauth.callbackScheme == "com.googleusercontent.apps.123-abc")
        #expect(url.host() == "accounts.google.com")
        #expect(value("redirect_uri") == "com.googleusercontent.apps.123-abc:/oauth2redirect")
        #expect(value("scope") == "https://www.googleapis.com/auth/photospicker.mediaitems.readonly")
        #expect(value("code_challenge_method") == "S256")
        #expect(value("response_type") == "code")
        #expect(value("state") == "state-1")
    }

    @Test func readsTheCodeOnlyWhenTheStateMatches() throws {
        let callback = URL(string: "com.googleusercontent.apps.123-abc:/oauth2redirect?state=s1&code=4/0Ab+c")!

        #expect(try GoogleOAuth.code(from: callback, state: "s1") == "4/0Ab+c")
        #expect(throws: GooglePhotosError.signInFailed) { try GoogleOAuth.code(from: callback, state: "other") }
    }

    @Test func treatsADeniedConsentAsCancelled() {
        let callback = URL(string: "com.googleusercontent.apps.123-abc:/oauth2redirect?error=access_denied&state=s1")!

        #expect(throws: GooglePhotosError.cancelled) { try GoogleOAuth.code(from: callback, state: "s1") }
    }

    @Test func keepsPlusSignsInTheTokenForm() throws {
        let form = String(decoding: oauth.tokenForm(code: "4/0Ab+c", verifier: "v"), as: UTF8.self)
        let items = try #require(URLComponents(string: "?" + form)?.queryItems)

        #expect(items.first { $0.name == "code" }?.value == "4/0Ab+c")
        #expect(items.first { $0.name == "grant_type" }?.value == "authorization_code")
        #expect(items.first { $0.name == "code_verifier" }?.value == "v")
    }

    @Test func decodesASessionAndOpensThePickerWithAutoclose() throws {
        let json = """
        {"id":"s1","pickerUri":"https://photos.google.com/picker/s1",\
        "pollingConfig":{"pollInterval":"3.5s","timeoutIn":"1799.2s"},"expireTime":"2027-05-14T09:30:00Z"}
        """
        let session = try JSONDecoder().decode(PickerSession.self, from: Data(json.utf8))

        #expect(session.pickerURL.absoluteString == "https://photos.google.com/picker/s1/autoclose")
        #expect(PickerPoll(session) == .wait(seconds: 3.5))
    }

    @Test(arguments: [
        (#"{"mediaItemsSet":true}"#, PickerPoll.ready),
        (#"{"pollingConfig":{"pollInterval":"2s","timeoutIn":"0s"}}"#, .timedOut),
        (#"{"pollingConfig":{"pollInterval":"0s","timeoutIn":"60s"}}"#, .wait(seconds: 1)),
        (#"{}"#, .wait(seconds: 5)),
    ])
    func decidesWhenToPollAgain(fields: String, expected: PickerPoll) throws {
        let base = #"{"id":"s1","pickerUri":"https://photos.google.com/picker/s1","#
        let json = base + fields.dropFirst()
        let session = try JSONDecoder().decode(PickerSession.self, from: Data(json.utf8))

        #expect(PickerPoll(session) == expected)
    }

    @Test func buildsDownloadURLsForPickedItems() throws {
        let json = """
        {"mediaItems":[
          {"id":"p1","createTime":"2027-05-14T09:00:00.123456789Z","type":"PHOTO",
           "mediaFile":{"baseUrl":"https://lh3.googleusercontent.com/p1","mimeType":"image/heic","filename":"IMG_1.HEIC",
           "mediaFileMetadata":{"width":4032,"height":3024,"cameraMake":"Apple","photoMetadata":{"isoEquivalent":50}}}},
          {"id":"v1","createTime":"2027-05-14T10:00:00Z","type":"VIDEO",
           "mediaFile":{"baseUrl":"https://lh3.googleusercontent.com/v1","mimeType":"video/mp4",
           "mediaFileMetadata":{"width":1920,"height":1080,"videoMetadata":{"fps":30,"processingStatus":"READY"}}}},
          {"id":"v2","type":"VIDEO",
           "mediaFile":{"baseUrl":"https://lh3.googleusercontent.com/v2","mimeType":"video/mp4",
           "mediaFileMetadata":{"videoMetadata":{"processingStatus":"PROCESSING"}}}}
        ],"nextPageToken":"next"}
        """
        let page = try JSONDecoder().decode(PickedMediaPage.self, from: Data(json.utf8))
        let items = try #require(page.mediaItems)

        #expect(page.nextPageToken == "next")
        #expect(items.map(\.kind) == [.photo, .video, .video])
        #expect(items.map(\.downloadURL?.absoluteString) == [
            "https://lh3.googleusercontent.com/p1=w2048-h2048",
            "https://lh3.googleusercontent.com/v1=dv",
            nil,
        ])
        #expect(try abs(#require(items[0].createdAt).timeIntervalSince1970 - 1810285200.123) < 0.001)
        #expect(items[1].createdAt == Date(timeIntervalSince1970: 1810288800))
    }

    @Test(arguments: [
        (GooglePhotosImportResult(imported: 3), "Dodano 3 elementy do galerii."),
        (GooglePhotosImportResult(imported: 5, skipped: 2, failed: 1), "Dodano 5 elementów do galerii. Już w galerii: 2. Nie udało się pobrać: 1."),
        (GooglePhotosImportResult(skipped: 4), "Już w galerii: 4."),
    ])
    func summarisesTheImport(result: GooglePhotosImportResult, expected: String) {
        #expect(result.summary == expected)
    }
}

@MainActor
struct GooglePhotosImporterTests {
    let backend = FakeBackend()
    let trip = Trip.fixture()
    let oauth = GoogleOAuth(clientID: "123-abc.apps.googleusercontent.com")

    private func importer(sleeps: Recorder<Double> = Recorder()) -> GooglePhotosImporter {
        GooglePhotosImporter(
            oauth: oauth,
            client: GooglePhotosClient(
                pickerURL: backend.baseURL.appending(path: "v1"),
                tokenURL: backend.baseURL.appending(path: "token"),
                revokeURL: backend.baseURL.appending(path: "revoke"),
                session: URLSession(configuration: backend.urlSessionConfiguration)
            ),
            now: { Date(timeIntervalSince1970: 1810285200) },
            sleep: { sleeps.append($0) }
        )
    }

    private func signIn(_ url: URL, _ scheme: String) throws(GooglePhotosError) -> URL {
        let state = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "state" }?.value ?? ""
        return URL(string: "\(scheme):/oauth2redirect?code=4/0Ab&state=\(state)")!
    }

    private func stubPicker(items: String) {
        backend.on("POST", "token", json: #"{"access_token":"g-token","expires_in":3599,"token_type":"Bearer"}"#)
        backend.on("POST", "v1/sessions", json: """
        {"id":"s1","pickerUri":"https://photos.google.com/picker/s1","pollingConfig":{"pollInterval":"2s","timeoutIn":"600s"}}
        """)
        backend.on("GET", "v1/sessions/s1", json: #"{"id":"s1","pickerUri":"https://photos.google.com/picker/s1","mediaItemsSet":true}"#)
        backend.on("GET", "v1/mediaItems", json: #"{"mediaItems":\#(items)}"#)
        backend.on("DELETE", "v1/sessions/s1", json: "{}")
    }

    private func photo(_ id: String) -> String {
        #"{"id":"\#(id)","createTime":"2027-05-14T09:00:00Z","type":"PHOTO","mediaFile":{"baseUrl":"\#(backend.baseURL.absoluteString)/lh/\#(id)","mimeType":"image/jpeg"}}"#
    }

    private func gallery(with json: String = #"{"media":[]}"#) async throws -> GalleryStore {
        backend.on("GET", "trips/t1/media", json: json)
        let gallery = GalleryStore(api: backend.api(backend.signedIn()))
        try await gallery.load(trip)
        return gallery
    }

    @Test func importsPickedPhotosAndSkipsOnesAlreadyInTheGallery() async throws {
        stubPicker(items: "[\(photo("g-new")),\(photo("g-old"))]")
        backend.on("GET", "lh/g-new=w2048-h2048", data: UIGraphicsImageRenderer(size: CGSize(width: 4, height: 3)).jpegData(withCompressionQuality: 0.8) { _ in })
        let gallery = try await gallery(with: """
        {"media":[{"id":"m1","kind":"photo","url":"https://s3/m1.jpg","thumbnailUrl":"https://s3/m1-thumb.jpg","contentType":"image/jpeg",\
        "width":4,"height":3,"durationSeconds":null,"takenAt":"2027-05-14T09:00:00.000Z","source":"google_photos","externalId":"g-old","uploadedBy":null}]}
        """)
        let sleeps = Recorder<Double>()
        let opened = Recorder<URL>()
        let importer = importer(sleeps: sleeps)

        await importer.run(into: trip, gallery: gallery, authenticate: signIn, open: { opened.append($0) })

        #expect(importer.phase == .finished(GooglePhotosImportResult(imported: 1, skipped: 1)))
        #expect(opened.values.map(\.absoluteString) == ["https://photos.google.com/picker/s1/autoclose"])
        #expect(sleeps.values == [2])
        #expect(backend.requests("GET", "v1/mediaItems").first?.query["sessionId"] == "s1")
        #expect(backend.requests("GET", "lh/g-new=w2048-h2048").first?.header("Authorization") == "Bearer g-token")
        #expect(backend.requests("GET", "lh/g-old=w2048-h2048").isEmpty)
        #expect(backend.requests("DELETE", "v1/sessions/s1").count == 1)
        #expect(gallery.uploads(for: trip).map(\.media.externalId) == ["g-new"])
        #expect(gallery.uploads(for: trip).first?.media.takenAt == Date(timeIntervalSince1970: 1810285200))
        #expect(importer.isConnected)
    }

    @Test func asksToSignInAgainWhenGoogleRejectsTheToken() async throws {
        stubPicker(items: "[]")
        backend.on("GET", "v1/mediaItems", status: 401, json: "{}")
        let importer = importer()

        await importer.run(into: trip, gallery: try await gallery(), authenticate: signIn, open: { _ in })

        #expect(importer.phase == .failed(GooglePhotosError.unauthorized.localizedDescription))
        #expect(!importer.isConnected)
        #expect(backend.requests("DELETE", "v1/sessions/s1").count == 1)
    }

    @Test func stopsWaitingWhenThePickerTimesOut() async throws {
        stubPicker(items: "[]")
        backend.on("GET", "v1/sessions/s1", json: #"{"id":"s1","pickerUri":"https://photos.google.com/picker/s1","pollingConfig":{"pollInterval":"2s","timeoutIn":"0s"}}"#)
        let importer = importer()

        await importer.run(into: trip, gallery: try await gallery(), authenticate: signIn, open: { _ in })

        #expect(importer.phase == .failed(GooglePhotosError.timedOut.localizedDescription))
        #expect(backend.requests("GET", "v1/mediaItems").isEmpty)
        #expect(backend.requests("DELETE", "v1/sessions/s1").count == 1)
    }

    @Test func doesNothingWhenSignInIsCancelled() async throws {
        let importer = importer()
        let gallery = try await gallery()

        await importer.run(into: trip, gallery: gallery, authenticate: { (_: URL, _: String) throws(GooglePhotosError) -> URL in throw .cancelled }, open: { _ in })

        #expect(importer.phase == .idle)
        #expect(backend.requests.filter { $0.path != "trips/t1/media" }.isEmpty)
    }
}

final class Recorder<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [Value] = []

    var values: [Value] {
        lock.withLock { recorded }
    }

    func append(_ value: Value) {
        lock.withLock { recorded.append(value) }
    }
}
