import Foundation
import Testing
@testable import zmykamy_pl

struct MediaModelsTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Lisbon")!
        return calendar
    }()

    private func item(_ id: String, _ kind: MediaKind = .photo, at iso: String, duration: Double? = nil) -> MediaItem {
        MediaItem(
            id: id,
            kind: kind,
            url: URL(string: "https://example.com/\(id)")!,
            thumbnailUrl: URL(string: "https://example.com/\(id)-thumb")!,
            contentType: kind == .photo ? "image/jpeg" : "video/mp4",
            width: 100,
            height: 100,
            durationSeconds: duration,
            takenAt: ISODateTime.date(from: iso)!,
            uploadedBy: nil
        )
    }

    @Test func decodesMediaFromTheApi() throws {
        let json = """
        {"media":[{"id":"m1","kind":"video","url":"https://s3/m1.mp4","thumbnailUrl":"https://s3/m1-thumb.jpg",\
        "contentType":"video/mp4","width":1280,"height":720,"durationSeconds":67.4,\
        "takenAt":"2027-05-14T09:00:00.000Z","uploadedBy":{"userId":"u1","name":"Zuza"}}]}
        """
        let list = try APIClient.decoder.decode(MediaList.self, from: Data(json.utf8))
        let media = try #require(list.media.first)

        #expect(media.kind == .video)
        #expect(media.durationText == "1:07")
        #expect(media.fileExtension == "mp4")
        #expect(media.takenAt == Date(timeIntervalSince1970: 1810285200))
        #expect(media.uploadedBy?.name == "Zuza")
    }

    @Test func groupsByLocalDayNewestFirst() {
        let items = [
            item("a", at: "2027-05-13T23:30:00Z"),
            item("b", at: "2027-05-13T10:00:00Z"),
            item("c", at: "2027-05-14T08:00:00Z"),
        ]
        let days = GalleryDay.group(items, calendar: Self.calendar)

        #expect(days.map(\.date) == [LocalDate(year: 2027, month: 5, day: 14), LocalDate(year: 2027, month: 5, day: 13)])
        #expect(days[0].items.map(\.id) == ["c", "a"])
    }

    @Test func countsPhotosAndVideosInPolish() {
        let photos = (1...5).map { item("p\($0)", at: "2027-05-13T10:00:00Z") }
        let videos = (1...2).map { item("v\($0)", .video, at: "2027-05-13T10:00:00Z") }

        #expect(GalleryFormat.counts([]) == "Brak zdjęć")
        #expect(GalleryFormat.counts(Array(photos.prefix(1))) == "1 zdjęcie")
        #expect(GalleryFormat.counts(Array(photos.prefix(3)) + Array(videos.prefix(1))) == "3 zdjęcia · 1 film")
        #expect(GalleryFormat.counts(photos + videos) == "5 zdjęć · 2 filmy")
    }

    @Test func filtersByKind() {
        let photo = item("p", at: "2027-05-13T10:00:00Z")
        let video = item("v", .video, at: "2027-05-13T10:00:00Z")

        #expect(GalleryFilter.photos.includes(photo) && !GalleryFilter.photos.includes(video))
        #expect(GalleryFilter.videos.includes(video) && !GalleryFilter.videos.includes(photo))
        #expect(GalleryFilter.all.includes(photo) && GalleryFilter.all.includes(video))
    }

    @Test func formatsLongVideoDurations() {
        #expect(item("v", .video, at: "2027-05-13T10:00:00Z", duration: 3725).durationText == "1:02:05")
        #expect(item("p", at: "2027-05-13T10:00:00Z", duration: 12).durationText == nil)
    }
}
