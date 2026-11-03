import Foundation

nonisolated struct TripTask: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let assigneeId: String?
    let dueDate: LocalDate?
    let isDone: Bool
    let completedAt: Date?
    let createdBy: String
}

nonisolated struct TripTaskRequest: Encodable, Sendable {
    let title: String
    let assigneeId: String?
    let dueDate: LocalDate?
}

nonisolated struct TripTaskUpdate: Encodable, Sendable {
    var title: String?
    var assigneeId: String??
    var dueDate: LocalDate??
    var isDone: Bool?
}
