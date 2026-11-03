import Foundation

nonisolated enum DocumentCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case ticket
    case reservation
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ticket: "Bilet"
        case .reservation: "Rezerwacja"
        case .other: "Inne"
        }
    }

    var sectionTitle: String {
        switch self {
        case .ticket: "BILETY"
        case .reservation: "REZERWACJE"
        case .other: "INNE"
        }
    }

    var defaultIcon: PlanIcon {
        switch self {
        case .ticket: .confirmationNumber
        case .reservation: .bed
        case .other: .info
        }
    }

    var isKeptOffline: Bool {
        self != .other
    }
}

nonisolated enum DocumentKind: String, Codable, Sendable {
    case file
    case link
}

nonisolated struct TripDocument: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let category: DocumentCategory
    let icon: PlanIcon
    let kind: DocumentKind
    let url: URL?
    let fileUrl: URL?
    let contentType: String?
    let planPointId: String?
    let author: PlanAuthor?
    let updatedAt: String

    var fileExtension: String {
        switch contentType {
        case "application/pdf": "pdf"
        case "image/png": "png"
        default: "jpg"
        }
    }

    var offlineFileName: String {
        "\(id).\(fileExtension)"
    }

    var typeLabel: String {
        switch (kind, contentType) {
        case (.link, _): "Link"
        case (_, "application/pdf"): "PDF"
        default: "Zdjęcie"
        }
    }
}

nonisolated struct DocumentList: Codable, Sendable {
    let documents: [TripDocument]
}

nonisolated struct DocumentUploadRequest: Encodable, Sendable {
    let contentType: String
}

nonisolated struct DocumentUploadTarget: Decodable, Sendable {
    let key: String
    let uploadUrl: URL
}

nonisolated struct DocumentRequest: Encodable, Sendable {
    let title: String
    let category: DocumentCategory
    let icon: PlanIcon
    let planPointId: String?
    let kind: DocumentKind?
    let key: String?
    let contentType: String?
    let url: URL?

    private enum CodingKeys: String, CodingKey {
        case title, category, icon, planPointId, kind, key, contentType, url
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(category, forKey: .category)
        try container.encode(icon, forKey: .icon)
        try container.encode(planPointId, forKey: .planPointId)
        try container.encodeIfPresent(kind, forKey: .kind)
        try container.encodeIfPresent(key, forKey: .key)
        try container.encodeIfPresent(contentType, forKey: .contentType)
        try container.encodeIfPresent(url, forKey: .url)
    }
}

nonisolated struct TripNote: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let text: String
    let pinned: Bool
    let author: PlanAuthor?
    let updatedAt: String

    var updatedDate: Date? {
        ISODateTime.date(from: updatedAt)
    }

    var isCode: Bool {
        !text.isEmpty && text.count <= 32 && !text.contains(where: \.isWhitespace)
    }
}

nonisolated struct NoteList: Codable, Sendable {
    let notes: [TripNote]
}

nonisolated struct NoteRequest: Encodable, Sendable {
    let title: String
    let text: String
    let pinned: Bool
}

nonisolated struct PickedDocumentFile: Sendable {
    let url: URL
    let contentType: String
}

nonisolated enum NoteFormat {
    private static let locale = Locale(identifier: "pl_PL")

    static func relative(_ date: Date?, now: Date = .now) -> String? {
        guard let date else { return nil }
        if now.timeIntervalSince(date) < 60 { return "przed chwilą" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }
}
