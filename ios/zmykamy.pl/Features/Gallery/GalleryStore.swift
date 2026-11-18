import Observation
import UIKit

@Observable
final class GalleryStore {
    struct Upload: Identifiable {
        let id = UUID()
        let tripID: Trip.ID
        let media: PreparedMedia
        let preview: UIImage?
        var isFailed = false
    }

    private(set) var items: [Trip.ID: [MediaItem]] = [:]
    private(set) var uploads: [Upload] = []

    private let api: AuthorizedAPI
    private var isSending = false

    init(api: AuthorizedAPI) {
        self.api = api
    }

    func media(for trip: Trip) -> [MediaItem]? {
        items[trip.id]
    }

    func uploads(for trip: Trip) -> [Upload] {
        uploads.filter { $0.tripID == trip.id }
    }

    func externalIDs(from source: MediaSource, in trip: Trip) -> Set<String> {
        let imported = (items[trip.id] ?? []).filter { $0.source == source }.compactMap(\.externalId)
        let pending = uploads(for: trip).filter { $0.media.source == source }.compactMap(\.media.externalId)
        return Set(imported + pending)
    }

    func load(_ trip: Trip) async throws(APIError) {
        let list: MediaList = try await api.call { (client, token) throws(APIError) in
            try await client.send("GET", "trips/\(trip.id)/media", token: token)
        }
        items[trip.id] = list.media
    }

    func enqueue(_ media: [PreparedMedia], to trip: Trip) {
        uploads += media.map { Upload(tripID: trip.id, media: $0, preview: UIImage(data: $0.thumbnail)) }
        sendPending()
    }

    func retry(_ upload: Upload) {
        guard let index = uploads.firstIndex(where: { $0.id == upload.id }) else { return }
        uploads[index].isFailed = false
        sendPending()
    }

    func discard(_ upload: Upload) {
        uploads.removeAll { $0.id == upload.id }
        MediaImport.discard(upload.media)
    }

    func delete(_ item: MediaItem, from trip: Trip) async throws(APIError) {
        try await api.call { (client, token) throws(APIError) in
            try await client.send("DELETE", "trips/\(trip.id)/media/\(item.id)", token: token)
        }
        items[trip.id]?.removeAll { $0.id == item.id }
    }

    private func sendPending() {
        guard !isSending else { return }
        isSending = true
        Task {
            let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "gallery-upload")
            while let upload = uploads.first(where: { !$0.isFailed }) {
                await send(upload)
            }
            UIApplication.shared.endBackgroundTask(backgroundTask)
            isSending = false
        }
    }

    private func send(_ upload: Upload) async {
        let media = upload.media
        do throws(APIError) {
            let target: MediaUploadTarget = try await api.call { (client, token) throws(APIError) in
                try await client.send(
                    "POST",
                    "trips/\(upload.tripID)/media/upload-url",
                    body: MediaUploadRequest(kind: media.kind, contentType: media.contentType),
                    token: token
                )
            }
            try await api.client.upload(fileAt: media.fileURL, to: target.uploadUrl, contentType: media.contentType)
            try await api.client.upload(media.thumbnail, to: target.thumbnailUploadUrl, contentType: "image/jpeg")
            let request = MediaCreateRequest(
                kind: media.kind,
                contentType: media.contentType,
                key: target.key,
                thumbnailKey: target.thumbnailKey,
                width: media.width,
                height: media.height,
                durationSeconds: media.durationSeconds,
                takenAt: ISODateTime.string(from: media.takenAt),
                source: media.source,
                externalId: media.externalId
            )
            let created: MediaItem = try await api.call { (client, token) throws(APIError) in
                try await client.send("POST", "trips/\(upload.tripID)/media", body: request, token: token)
            }
            items[upload.tripID, default: []].append(created)
            items[upload.tripID]?.sort { $0.takenAt > $1.takenAt }
            discard(upload)
        } catch .server(_, "media_already_imported") {
            discard(upload)
        } catch {
            guard let index = uploads.firstIndex(where: { $0.id == upload.id }) else { return }
            uploads[index].isFailed = true
        }
    }
}
