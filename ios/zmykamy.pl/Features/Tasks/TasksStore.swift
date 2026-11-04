import Observation

@Observable
final class TasksStore {
    private(set) var tasks: [Trip.ID: [TripTask]] = [:]

    private let api: AuthorizedAPI

    init(api: AuthorizedAPI, tasks: [Trip.ID: [TripTask]] = [:]) {
        self.api = api
        self.tasks = tasks
    }

    func tasks(for trip: Trip) -> [TripTask]? {
        tasks[trip.id]
    }

    func load(_ trip: Trip) async throws(APIError) {
        tasks[trip.id] = try await api.call { (client, token) throws(APIError) in
            try await client.send("GET", "trips/\(trip.id)/tasks", token: token)
        }
    }

    func add(_ request: TripTaskRequest, to trip: Trip) async throws(APIError) {
        let created: TripTask = try await api.call { (client, token) throws(APIError) in
            try await client.send("POST", "trips/\(trip.id)/tasks", body: request, token: token)
        }
        change(trip) { $0.append(created) }
    }

    func update(_ task: TripTask, with update: TripTaskUpdate, in trip: Trip) async throws(APIError) {
        let updated: TripTask = try await api.call { (client, token) throws(APIError) in
            try await client.send("PATCH", "trips/\(trip.id)/tasks/\(task.id)", body: update, token: token)
        }
        change(trip) { tasks in
            guard let index = tasks.firstIndex(where: { $0.id == updated.id }) else { return }
            tasks[index] = updated
        }
    }

    func delete(_ task: TripTask, from trip: Trip) async throws(APIError) {
        try await api.call { (client, token) throws(APIError) in
            try await client.send("DELETE", "trips/\(trip.id)/tasks/\(task.id)", token: token)
        }
        change(trip) { $0.removeAll { $0.id == task.id } }
    }

    private func change(_ trip: Trip, _ mutation: (inout [TripTask]) -> Void) {
        var list = tasks[trip.id] ?? []
        mutation(&list)
        list.sort { a, b in
            switch (a.dueDate, b.dueDate) {
            case let (a?, b?): a < b
            case (_?, nil): true
            default: false
            }
        }
        tasks[trip.id] = list
    }
}
