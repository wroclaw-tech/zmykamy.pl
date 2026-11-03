import Foundation

nonisolated enum PackingScope: String, Codable, Sendable {
    case personal
    case shared
}

nonisolated struct PackingItem: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let scope: PackingScope
    let name: String
    let assigneeId: String?
    let isPacked: Bool
    let createdBy: String
}

nonisolated struct PackingItemRequest: Encodable, Sendable {
    let scope: PackingScope
    let name: String
}

nonisolated struct PackingItemUpdate: Encodable, Sendable {
    var name: String?
    var assigneeId: String??
    var isPacked: Bool?
}
