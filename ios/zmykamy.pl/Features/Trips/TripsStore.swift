import Observation
import UIKit

@Observable
final class TripsStore {
    private(set) var trips: [Trip] = []
    private(set) var hasLoaded = false

    let api: AuthorizedAPI
    private let client: APIClient

    private static let coverMaxDimension: CGFloat = 2048
    private static let coverContentType = "image/jpeg"

    init(auth: AuthStore, client: APIClient = APIClient()) {
        self.api = AuthorizedAPI(auth: auth, client: client)
        self.client = client
    }

    func trip(id: Trip.ID) -> Trip? {
        trips.first { $0.id == id }
    }

    func load() async throws(APIError) {
        trips = try await call { (client, token) throws(APIError) in
            try await client.send("GET", "trips", token: token)
        }
        hasLoaded = true
    }

    func create(_ request: TripRequest) async throws(APIError) -> Trip {
        let trip: Trip = try await call { (client, token) throws(APIError) in
            try await client.send("POST", "trips", body: request, token: token)
        }
        trips.append(trip)
        return trip
    }

    func update(_ trip: Trip, with request: TripRequest) async throws(APIError) {
        let updated: Trip = try await call { (client, token) throws(APIError) in
            try await client.send("PATCH", "trips/\(trip.id)", body: request, token: token)
        }
        replace(updated)
    }

    /// Uploads the photo through a presigned URL and sets it as the cover; `nil` removes the cover.
    func setCover(of trip: Trip, to image: UIImage?) async throws(APIError) {
        let key: String?
        if let image {
            guard let data = Self.coverData(from: image) else { throw .validation }
            let upload: CoverUploadResponse = try await call { (client, token) throws(APIError) in
                try await client.send("POST", "trips/\(trip.id)/cover/upload-url", token: token)
            }
            try await client.upload(data, to: upload.uploadUrl, contentType: Self.coverContentType)
            key = upload.key
        } else {
            key = nil
        }
        let updated: Trip = try await call { (client, token) throws(APIError) in
            try await client.send("PATCH", "trips/\(trip.id)", body: TripCoverRequest(coverImageKey: key), token: token)
        }
        replace(updated)
    }

    func reload(_ tripID: Trip.ID) async throws(APIError) {
        let updated: Trip = try await call { (client, token) throws(APIError) in
            try await client.send("GET", "trips/\(tripID)", token: token)
        }
        replace(updated)
    }

    func delete(_ trip: Trip) async throws(APIError) {
        try await call { (client, token) throws(APIError) in
            try await client.send("DELETE", "trips/\(trip.id)", token: token)
        }
        trips.removeAll { $0.id == trip.id }
    }

    func invite(for trip: Trip) async throws(APIError) -> TripInvite {
        try await call { (client, token) throws(APIError) in
            try await client.send("GET", "trips/\(trip.id)/invite", token: token)
        }
    }

    func regenerateInvite(of trip: Trip) async throws(APIError) -> TripInvite {
        try await call { (client, token) throws(APIError) in
            try await client.send("POST", "trips/\(trip.id)/invite/regenerate", token: token)
        }
    }

    func remove(_ member: TripMember, from trip: Trip) async throws(APIError) {
        try await call { (client, token) throws(APIError) in
            try await client.send("DELETE", "trips/\(trip.id)/members/\(member.userId)", token: token)
        }
        let updated: Trip = try await call { (client, token) throws(APIError) in
            try await client.send("GET", "trips/\(trip.id)", token: token)
        }
        replace(updated)
    }

    func leave(_ trip: Trip) async throws(APIError) {
        try await call { (client, token) throws(APIError) in
            try await client.send("DELETE", "trips/\(trip.id)/members/me", token: token)
        }
        trips.removeAll { $0.id == trip.id }
    }

    func preview(inviteCode code: String) async throws(APIError) -> InvitePreview {
        try await client.send("GET", "invites/\(code)")
    }

    func join(inviteCode code: String) async throws(APIError) -> Trip {
        let joined: Trip = try await call { (client, token) throws(APIError) in
            try await client.send("POST", "invites/\(code)/join", token: token)
        }
        if trips.contains(where: { $0.id == joined.id }) {
            replace(joined)
        } else {
            trips.append(joined)
        }
        return joined
    }

    private func replace(_ trip: Trip) {
        guard let index = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        trips[index] = trip
    }

    private func call<Response>(
        _ request: (APIClient, String) async throws(APIError) -> Response
    ) async throws(APIError) -> Response {
        try await api.call(request)
    }

    private static func coverData(from image: UIImage) -> Data? {
        let scale = min(1, coverMaxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
