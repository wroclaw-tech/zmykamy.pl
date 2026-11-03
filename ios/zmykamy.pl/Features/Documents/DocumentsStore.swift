import Observation
import Foundation

@Observable
final class DocumentsStore {
    private(set) var documents: [Trip.ID: [TripDocument]] = [:]
    private(set) var notes: [Trip.ID: [TripNote]] = [:]
    private(set) var offlineTrips: Set<Trip.ID> = []
    private(set) var downloadedFiles: Set<String> = []

    private let api: AuthorizedAPI

    init(api: AuthorizedAPI) {
        self.api = api
    }

    func documents(for trip: Trip) -> [TripDocument]? {
        documents[trip.id]
    }

    func documents(attachedTo point: PlanPoint, in trip: Trip) -> [TripDocument] {
        (documents[trip.id] ?? []).filter { $0.planPointId == point.id }
    }

    func notes(for trip: Trip) -> [TripNote]? {
        notes[trip.id]
    }

    func isOffline(_ trip: Trip) -> Bool {
        offlineTrips.contains(trip.id)
    }

    func isAvailableOffline(_ document: TripDocument) -> Bool {
        document.kind == .file && downloadedFiles.contains(document.offlineFileName)
    }

    func load(_ trip: Trip) async throws(APIError) {
        do throws(APIError) {
            let documentList: DocumentList = try await api.call { (client, token) throws(APIError) in
                try await client.send("GET", "trips/\(trip.id)/documents", token: token)
            }
            let noteList: NoteList = try await api.call { (client, token) throws(APIError) in
                try await client.send("GET", "trips/\(trip.id)/notes", token: token)
            }
            documents[trip.id] = documentList.documents
            notes[trip.id] = noteList.notes
            offlineTrips.remove(trip.id)
            persist(trip)
            refreshDownloaded(trip)
            await downloadForOffline(trip)
        } catch .network {
            guard let cachedDocuments = OfflineCache.load([TripDocument].self, name: documentsCacheName(trip)),
                  let cachedNotes = OfflineCache.load([TripNote].self, name: notesCacheName(trip)) else {
                throw .network
            }
            documents[trip.id] = cachedDocuments
            notes[trip.id] = cachedNotes
            offlineTrips.insert(trip.id)
            refreshDownloaded(trip)
        }
    }

    func loadIfNeeded(_ trip: Trip) async {
        guard documents[trip.id] == nil else { return }
        try? await load(trip)
    }

    func addFile(_ file: PickedDocumentFile, request: DocumentRequest, to trip: Trip) async throws(APIError) {
        let target: DocumentUploadTarget = try await api.call { (client, token) throws(APIError) in
            try await client.send(
                "POST",
                "trips/\(trip.id)/documents/upload-url",
                body: DocumentUploadRequest(contentType: file.contentType),
                token: token
            )
        }
        try await api.client.upload(fileAt: file.url, to: target.uploadUrl, contentType: file.contentType)
        let body = DocumentRequest(
            title: request.title,
            category: request.category,
            icon: request.icon,
            planPointId: request.planPointId,
            kind: .file,
            key: target.key,
            contentType: file.contentType,
            url: nil
        )
        let created: TripDocument = try await api.call { (client, token) throws(APIError) in
            try await client.send("POST", "trips/\(trip.id)/documents", body: body, token: token)
        }
        if created.category.isKeptOffline, let stored = try? OfflineCache.storeFile(at: copy(of: file.url), named: created.offlineFileName) {
            downloadedFiles.insert(stored.lastPathComponent)
        }
        changeDocuments(trip) { $0.append(created) }
    }

    func addLink(_ request: DocumentRequest, to trip: Trip) async throws(APIError) {
        let created: TripDocument = try await api.call { (client, token) throws(APIError) in
            try await client.send("POST", "trips/\(trip.id)/documents", body: request, token: token)
        }
        changeDocuments(trip) { $0.append(created) }
    }

    func update(_ document: TripDocument, with request: DocumentRequest, in trip: Trip) async throws(APIError) {
        let updated: TripDocument = try await api.call { (client, token) throws(APIError) in
            try await client.send("PATCH", "trips/\(trip.id)/documents/\(document.id)", body: request, token: token)
        }
        changeDocuments(trip) { list in
            guard let index = list.firstIndex(where: { $0.id == updated.id }) else { return }
            list[index] = updated
        }
    }

    func delete(_ document: TripDocument, from trip: Trip) async throws(APIError) {
        try await api.call { (client, token) throws(APIError) in
            try await client.send("DELETE", "trips/\(trip.id)/documents/\(document.id)", token: token)
        }
        OfflineCache.removeFile(named: document.offlineFileName)
        downloadedFiles.remove(document.offlineFileName)
        changeDocuments(trip) { $0.removeAll { $0.id == document.id } }
    }

    func localFile(for document: TripDocument) async throws(APIError) -> URL {
        let cached = OfflineCache.fileURL(named: document.offlineFileName)
        if FileManager.default.fileExists(atPath: cached.path()) {
            return cached
        }
        guard let remote = document.fileUrl else { throw .notFound }
        do {
            let (location, response) = try await URLSession.shared.download(from: remote)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw APIError.network }
            let stored = try OfflineCache.storeFile(at: location, named: document.offlineFileName)
            downloadedFiles.insert(document.offlineFileName)
            return stored
        } catch {
            throw .network
        }
    }

    func addNote(_ request: NoteRequest, to trip: Trip) async throws(APIError) {
        let created: TripNote = try await api.call { (client, token) throws(APIError) in
            try await client.send("POST", "trips/\(trip.id)/notes", body: request, token: token)
        }
        changeNotes(trip) { $0.append(created) }
    }

    func update(_ note: TripNote, with request: NoteRequest, in trip: Trip) async throws(APIError) {
        let updated: TripNote = try await api.call { (client, token) throws(APIError) in
            try await client.send("PATCH", "trips/\(trip.id)/notes/\(note.id)", body: request, token: token)
        }
        changeNotes(trip) { list in
            guard let index = list.firstIndex(where: { $0.id == updated.id }) else { return }
            list[index] = updated
        }
    }

    func delete(_ note: TripNote, from trip: Trip) async throws(APIError) {
        try await api.call { (client, token) throws(APIError) in
            try await client.send("DELETE", "trips/\(trip.id)/notes/\(note.id)", token: token)
        }
        changeNotes(trip) { $0.removeAll { $0.id == note.id } }
    }

    private func downloadForOffline(_ trip: Trip) async {
        for document in documents[trip.id] ?? [] where document.kind == .file && document.category.isKeptOffline {
            _ = try? await localFile(for: document)
        }
    }

    private func refreshDownloaded(_ trip: Trip) {
        for document in documents[trip.id] ?? [] where document.kind == .file {
            if FileManager.default.fileExists(atPath: OfflineCache.fileURL(named: document.offlineFileName).path()) {
                downloadedFiles.insert(document.offlineFileName)
            }
        }
    }

    private func copy(of url: URL) throws -> URL {
        let destination = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.copyItem(at: url, to: destination)
        return destination
    }

    private func documentsCacheName(_ trip: Trip) -> String {
        "trip-\(trip.id)-documents"
    }

    private func notesCacheName(_ trip: Trip) -> String {
        "trip-\(trip.id)-notes"
    }

    private func persist(_ trip: Trip) {
        if let list = documents[trip.id] {
            OfflineCache.save(list, as: documentsCacheName(trip))
        }
        if let list = notes[trip.id] {
            OfflineCache.save(list, as: notesCacheName(trip))
        }
    }

    private func changeDocuments(_ trip: Trip, _ mutation: (inout [TripDocument]) -> Void) {
        var list = documents[trip.id] ?? []
        mutation(&list)
        documents[trip.id] = list
        persist(trip)
    }

    private func changeNotes(_ trip: Trip, _ mutation: (inout [TripNote]) -> Void) {
        var list = notes[trip.id] ?? []
        mutation(&list)
        list.sort { ($0.pinned ? 1 : 0, $0.updatedAt) > ($1.pinned ? 1 : 0, $1.updatedAt) }
        notes[trip.id] = list
        persist(trip)
    }
}
