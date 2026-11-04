import Observation

@Observable
final class PackingStore {
    private(set) var items: [Trip.ID: [PackingItem]] = [:]

    private let api: AuthorizedAPI

    init(api: AuthorizedAPI, items: [Trip.ID: [PackingItem]] = [:]) {
        self.api = api
        self.items = items
    }

    func items(for trip: Trip, scope: PackingScope) -> [PackingItem]? {
        items[trip.id]?.filter { $0.scope == scope }
    }

    func load(_ trip: Trip) async throws(APIError) {
        items[trip.id] = try await api.call { (client, token) throws(APIError) in
            try await client.send("GET", "trips/\(trip.id)/packing", token: token)
        }
    }

    func add(_ request: PackingItemRequest, to trip: Trip) async throws(APIError) {
        let created: PackingItem = try await api.call { (client, token) throws(APIError) in
            try await client.send("POST", "trips/\(trip.id)/packing", body: request, token: token)
        }
        items[trip.id, default: []].append(created)
    }

    func update(_ item: PackingItem, with update: PackingItemUpdate, in trip: Trip) async throws(APIError) {
        let updated: PackingItem = try await api.call { (client, token) throws(APIError) in
            try await client.send("PATCH", "trips/\(trip.id)/packing/\(item.id)", body: update, token: token)
        }
        guard let index = items[trip.id]?.firstIndex(where: { $0.id == updated.id }) else { return }
        items[trip.id]?[index] = updated
    }

    func delete(_ item: PackingItem, from trip: Trip) async throws(APIError) {
        try await api.call { (client, token) throws(APIError) in
            try await client.send("DELETE", "trips/\(trip.id)/packing/\(item.id)", token: token)
        }
        items[trip.id]?.removeAll { $0.id == item.id }
    }
}
