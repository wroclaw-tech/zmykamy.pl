import Observation

@Observable
final class PlanStore {
    private(set) var plans: [Trip.ID: TripPlan] = [:]
    private(set) var weather: [Trip.ID: TripWeather] = [:]

    private let api: AuthorizedAPI

    init(api: AuthorizedAPI) {
        self.api = api
    }

    func plan(for trip: Trip) -> TripPlan? {
        plans[trip.id]
    }

    func load(_ trip: Trip) async throws(APIError) {
        do throws(APIError) {
            let plan: TripPlan = try await api.call { (client, token) throws(APIError) in
                try await client.send("GET", "trips/\(trip.id)/plan", token: token)
            }
            plans[trip.id] = plan
            OfflineCache.save(plan, as: cacheName(trip))
        } catch .network {
            guard let cached = OfflineCache.load(TripPlan.self, name: cacheName(trip)) else { throw .network }
            plans[trip.id] = cached
        }
    }

    private func cacheName(_ trip: Trip) -> String {
        "trip-\(trip.id)-plan"
    }

    func weather(for trip: Trip) -> TripWeather? {
        weather[trip.id]
    }

    /// Forecast for the trip days; keeps the last one seen when it can't be refreshed,
    /// since weather is only a hint.
    func loadWeather(_ trip: Trip) async {
        let cacheName = "trip-\(trip.id)-weather"
        do throws(APIError) {
            let forecast: TripWeather = try await api.call { (client, token) throws(APIError) in
                try await client.send("GET", "trips/\(trip.id)/weather", token: token)
            }
            weather[trip.id] = forecast
            OfflineCache.save(forecast, as: cacheName)
        } catch {
            if weather[trip.id] == nil {
                weather[trip.id] = OfflineCache.load(TripWeather.self, name: cacheName)
            }
        }
    }

    func addPoint(_ request: PlanPointRequest, to trip: Trip) async throws(APIError) {
        let created: PlanPoint = try await api.call { (client, token) throws(APIError) in
            try await client.send("POST", "trips/\(trip.id)/plan/points", body: request, token: token)
        }
        change(trip) { $0.points.append(created) }
    }

    func update(_ point: PlanPoint, with request: PlanPointRequest, in trip: Trip) async throws(APIError) {
        let updated: PlanPoint = try await api.call { (client, token) throws(APIError) in
            try await client.send("PATCH", "trips/\(trip.id)/plan/points/\(point.id)", body: request, token: token)
        }
        change(trip) { plan in
            guard let index = plan.points.firstIndex(where: { $0.id == updated.id }) else { return }
            plan.points[index] = updated
        }
    }

    func delete(_ point: PlanPoint, from trip: Trip) async throws(APIError) {
        try await api.call { (client, token) throws(APIError) in
            try await client.send("DELETE", "trips/\(trip.id)/plan/points/\(point.id)", token: token)
        }
        change(trip) { $0.points.removeAll { $0.id == point.id } }
    }

    func addInfo(_ request: TripInfoRequest, to trip: Trip) async throws(APIError) {
        let created: TripInfoCard = try await api.call { (client, token) throws(APIError) in
            try await client.send("POST", "trips/\(trip.id)/plan/info", body: request, token: token)
        }
        change(trip) { $0.info.append(created) }
    }

    func update(_ card: TripInfoCard, with request: TripInfoRequest, in trip: Trip) async throws(APIError) {
        let updated: TripInfoCard = try await api.call { (client, token) throws(APIError) in
            try await client.send("PATCH", "trips/\(trip.id)/plan/info/\(card.id)", body: request, token: token)
        }
        change(trip) { plan in
            guard let index = plan.info.firstIndex(where: { $0.id == updated.id }) else { return }
            plan.info[index] = updated
        }
    }

    func delete(_ card: TripInfoCard, from trip: Trip) async throws(APIError) {
        try await api.call { (client, token) throws(APIError) in
            try await client.send("DELETE", "trips/\(trip.id)/plan/info/\(card.id)", token: token)
        }
        change(trip) { $0.info.removeAll { $0.id == card.id } }
    }

    private func change(_ trip: Trip, _ mutation: (inout TripPlan) -> Void) {
        var plan = plans[trip.id] ?? .empty
        mutation(&plan)
        plan.points.sort { ($0.date, $0.time) < ($1.date, $1.time) }
        plans[trip.id] = plan
        OfflineCache.save(plan, as: cacheName(trip))
    }
}
