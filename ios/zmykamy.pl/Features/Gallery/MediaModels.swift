import Foundation

nonisolated enum MediaKind: String, Codable, Sendable {
    case photo
    case video
}

nonisolated struct MediaItem: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let kind: MediaKind
    let url: URL
    let thumbnailUrl: URL
    let contentType: String
    let width: Int
    let height: Int
    let durationSeconds: Double?
    let takenAt: Date
    let uploadedBy: ExpensePerson?

    private enum CodingKeys: String, CodingKey {
        case id, kind, url, thumbnailUrl, contentType, width, height, durationSeconds, takenAt, uploadedBy
    }

    init(
        id: String,
        kind: MediaKind,
        url: URL,
        thumbnailUrl: URL,
        contentType: String,
        width: Int,
        height: Int,
        durationSeconds: Double?,
        takenAt: Date,
        uploadedBy: ExpensePerson?
    ) {
        self.id = id
        self.kind = kind
        self.url = url
        self.thumbnailUrl = thumbnailUrl
        self.contentType = contentType
        self.width = width
        self.height = height
        self.durationSeconds = durationSeconds
        self.takenAt = takenAt
        self.uploadedBy = uploadedBy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(MediaKind.self, forKey: .kind)
        url = try container.decode(URL.self, forKey: .url)
        thumbnailUrl = try container.decode(URL.self, forKey: .thumbnailUrl)
        contentType = try container.decode(String.self, forKey: .contentType)
        width = try container.decode(Int.self, forKey: .width)
        height = try container.decode(Int.self, forKey: .height)
        durationSeconds = try container.decodeIfPresent(Double.self, forKey: .durationSeconds)
        uploadedBy = try container.decodeIfPresent(ExpensePerson.self, forKey: .uploadedBy)
        let raw = try container.decode(String.self, forKey: .takenAt)
        guard let date = ISODateTime.date(from: raw) else {
            throw DecodingError.dataCorruptedError(forKey: .takenAt, in: container, debugDescription: "Invalid date: \(raw)")
        }
        takenAt = date
    }

    var durationText: String? {
        guard kind == .video, let durationSeconds else { return nil }
        let total = Int(durationSeconds.rounded())
        return total >= 3600
            ? String(format: "%d:%02d:%02d", total / 3600, total % 3600 / 60, total % 60)
            : String(format: "%d:%02d", total / 60, total % 60)
    }

    var fileExtension: String {
        switch contentType {
        case "video/mp4": "mp4"
        case "video/quicktime": "mov"
        default: "jpg"
        }
    }
}

nonisolated struct MediaList: Decodable, Sendable {
    let media: [MediaItem]
}

nonisolated struct MediaUploadRequest: Encodable, Sendable {
    let kind: MediaKind
    let contentType: String
}

nonisolated struct MediaUploadTarget: Decodable, Sendable {
    let key: String
    let uploadUrl: URL
    let thumbnailKey: String
    let thumbnailUploadUrl: URL
}

nonisolated struct MediaCreateRequest: Encodable, Sendable {
    let kind: MediaKind
    let contentType: String
    let key: String
    let thumbnailKey: String
    let width: Int
    let height: Int
    let durationSeconds: Double?
    let takenAt: String
}

nonisolated enum ISODateTime {
    static func date(from string: String) -> Date? {
        (try? Date(string, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
            ?? (try? Date(string, strategy: .iso8601))
    }

    static func string(from date: Date) -> String {
        date.formatted(.iso8601)
    }
}

nonisolated enum GalleryFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "Wszystko"
    case photos = "Zdjęcia"
    case videos = "Filmy"

    var id: String { rawValue }

    func includes(_ item: MediaItem) -> Bool {
        switch self {
        case .all: true
        case .photos: item.kind == .photo
        case .videos: item.kind == .video
        }
    }
}

nonisolated struct GalleryDay: Identifiable, Equatable, Sendable {
    let date: LocalDate
    let items: [MediaItem]

    var id: LocalDate { date }

    static func group(_ items: [MediaItem], calendar: Calendar) -> [GalleryDay] {
        Dictionary(grouping: items) { LocalDate($0.takenAt, calendar: calendar) }
            .map { GalleryDay(date: $0.key, items: $0.value.sorted { $0.takenAt > $1.takenAt }) }
            .sorted { $0.date > $1.date }
    }
}

nonisolated enum GalleryFormat {
    static func counts(_ items: [MediaItem]) -> String {
        let photos = items.filter { $0.kind == .photo }.count
        let videos = items.count - photos
        let photoText = "\(photos) \(PolishPlural.form(photos, one: "zdjęcie", few: "zdjęcia", many: "zdjęć"))"
        let videoText = "\(videos) \(PolishPlural.form(videos, one: "film", few: "filmy", many: "filmów"))"
        switch (photos, videos) {
        case (0, 0): return "Brak zdjęć"
        case (_, 0): return photoText
        case (0, _): return videoText
        default: return "\(photoText) · \(videoText)"
        }
    }

    static func places(on date: LocalDate, in plan: TripPlan?) -> String? {
        var seen = Set<String>()
        let places = (plan?.points(on: date) ?? [])
            .compactMap { $0.place?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
            .prefix(2)
        return places.isEmpty ? nil : places.joined(separator: " i ")
    }
}
