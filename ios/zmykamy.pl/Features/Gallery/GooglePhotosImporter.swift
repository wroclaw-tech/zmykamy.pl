import Foundation
import Observation

@Observable
final class GooglePhotosImporter {
    enum Phase: Equatable {
        case idle
        case signingIn
        case picking(URL?)
        case downloading(done: Int, total: Int)
        case finished(GooglePhotosImportResult)
        case failed(String)
    }

    typealias Authenticate = (URL, String) async throws(GooglePhotosError) -> URL

    let oauth: GoogleOAuth?
    private(set) var phase = Phase.idle
    private(set) var tripID: Trip.ID?
    private(set) var lastImport: [Trip.ID: Date] = [:]
    private var token: GoogleAccessToken?

    private let client: GooglePhotosClient
    private let now: () -> Date
    private let sleep: (Double) async throws -> Void
    private var task: Task<Void, Never>?

    init(
        oauth: GoogleOAuth? = .configured,
        client: GooglePhotosClient = GooglePhotosClient(),
        now: @escaping () -> Date = { .now },
        sleep: @escaping (Double) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }
    ) {
        self.oauth = oauth
        self.client = client
        self.now = now
        self.sleep = sleep
    }

    var isConnected: Bool {
        token?.isUsable(at: now()) == true
    }

    var isRunning: Bool {
        switch phase {
        case .signingIn, .picking, .downloading: true
        case .idle, .finished, .failed: false
        }
    }

    func phase(for trip: Trip) -> Phase {
        tripID == trip.id ? phase : .idle
    }

    func start(into trip: Trip, gallery: GalleryStore, authenticate: @escaping Authenticate, open: @escaping (URL) -> Void) {
        guard oauth != nil, !isRunning else { return }
        phase = .signingIn
        tripID = trip.id
        task = Task { await run(into: trip, gallery: gallery, authenticate: authenticate, open: open) }
    }

    func cancel() {
        task?.cancel()
    }

    func disconnect() {
        guard let token, !isRunning else { return }
        self.token = nil
        Task { await client.revoke(token) }
    }

    func run(into trip: Trip, gallery: GalleryStore, authenticate: Authenticate, open: (URL) -> Void) async {
        guard let oauth else { return }
        tripID = trip.id
        phase = .signingIn
        var cleanup: (session: String, token: GoogleAccessToken)?
        do throws(GooglePhotosError) {
            let token = try await validToken(oauth, authenticate: authenticate)
            phase = .picking(nil)
            let session = try await client.createSession(token: token)
            cleanup = (session.id, token)
            open(session.pickerURL)
            phase = .picking(session.pickerURL)
            try await waitForPick(session, token: token)
            let picked = try await client.mediaItems(in: session.id, token: token)
            let result = try await download(picked, into: trip, gallery: gallery, token: token)
            lastImport[trip.id] = now()
            phase = .finished(result)
        } catch .cancelled {
            phase = .idle
        } catch {
            if error == .unauthorized { token = nil }
            phase = .failed(error.localizedDescription)
        }
        if let cleanup {
            await Task { await client.deleteSession(cleanup.session, token: cleanup.token) }.value
        }
        task = nil
    }

    private func validToken(_ oauth: GoogleOAuth, authenticate: Authenticate) async throws(GooglePhotosError) -> GoogleAccessToken {
        if let token, token.isUsable(at: now()) { return token }
        let pkce = PKCE.random()
        let state = PKCE.randomString(bytes: 16)
        let callback = try await authenticate(oauth.authorizationURL(challenge: pkce.challenge, state: state), oauth.callbackScheme)
        let code = try GoogleOAuth.code(from: callback, state: state)
        let token = try await client.exchange(code: code, verifier: pkce.verifier, oauth: oauth, now: now())
        self.token = token
        return token
    }

    private func waitForPick(_ session: PickerSession, token: GoogleAccessToken) async throws(GooglePhotosError) {
        var current = session
        while true {
            switch PickerPoll(current) {
            case .ready:
                return
            case .timedOut:
                throw .timedOut
            case .wait(let seconds):
                do {
                    try await sleep(seconds)
                } catch {
                    throw .cancelled
                }
                current = try await client.session(session.id, token: token)
            }
        }
    }

    private func download(
        _ picked: [PickedMediaItem],
        into trip: Trip,
        gallery: GalleryStore,
        token: GoogleAccessToken
    ) async throws(GooglePhotosError) -> GooglePhotosImportResult {
        let existing = gallery.externalIDs(from: .googlePhotos, in: trip)
        let fresh = picked.filter { !existing.contains($0.id) }
        var result = GooglePhotosImportResult(skipped: picked.count - fresh.count)
        for (index, item) in fresh.enumerated() {
            phase = .downloading(done: index, total: fresh.count)
            if Task.isCancelled { throw .cancelled }
            if let media = try await prepare(item, token: token) {
                gallery.enqueue([media], to: trip)
                result.imported += 1
            } else {
                result.failed += 1
            }
        }
        return result
    }

    private func prepare(_ item: PickedMediaItem, token: GoogleAccessToken) async throws(GooglePhotosError) -> PreparedMedia? {
        guard let kind = item.kind, let url = item.downloadURL else { return nil }
        let file: URL
        do throws(GooglePhotosError) {
            file = try await client.download(url, fileExtension: kind == .video ? "mp4" : "jpg", token: token)
        } catch .unauthorized {
            throw .unauthorized
        } catch {
            if Task.isCancelled { throw .cancelled }
            return nil
        }
        var media: PreparedMedia?
        switch kind {
        case .photo:
            let data = try? Data(contentsOf: file)
            try? FileManager.default.removeItem(at: file)
            if let data {
                media = await MediaImport.photo(from: data, takenAt: item.createdAt)
            }
        case .video:
            media = await MediaImport.video(at: file, takenAt: item.createdAt)
            if media == nil {
                try? FileManager.default.removeItem(at: file)
            }
        }
        media?.source = .googlePhotos
        media?.externalId = item.id
        return media
    }
}
