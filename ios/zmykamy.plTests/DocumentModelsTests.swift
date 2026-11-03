import Foundation
import Testing
@testable import zmykamy_pl

struct DocumentModelsTests {
    @Test func decodesDocumentsFromTheApi() throws {
        let json = """
        {"documents":[{"id":"d1","title":"Karty pokładowe","category":"ticket","icon":"flight_takeoff","kind":"file",\
        "url":null,"fileUrl":"https://s3/d1.pdf","contentType":"application/pdf","planPointId":"p1",\
        "author":{"userId":"u1","name":"Michał"},"createdAt":"2027-05-01T10:00:00.000Z","updatedAt":"2027-05-01T10:00:00.000Z"},\
        {"id":"d2","title":"Mieszkanie","category":"reservation","icon":"bed","kind":"link",\
        "url":"https://example.com/booking","fileUrl":null,"contentType":null,"planPointId":null,\
        "author":null,"createdAt":"2027-05-01T10:00:00.000Z","updatedAt":"2027-05-01T10:00:00.000Z"}]}
        """
        let list = try APIClient.decoder.decode(DocumentList.self, from: Data(json.utf8))

        #expect(list.documents.map(\.typeLabel) == ["PDF", "Link"])
        #expect(list.documents[0].offlineFileName == "d1.pdf")
        #expect(list.documents[0].planPointId == "p1")
        #expect(list.documents[1].url == URL(string: "https://example.com/booking"))
    }

    @Test func roundTripsThroughTheOfflineCacheEncoding() throws {
        let note = TripNote(id: "n1", title: "Wi-Fi", text: "sardynki2027", pinned: true, author: nil, updatedAt: "2027-05-01T10:00:00.000Z")
        let data = try JSONEncoder().encode([note])
        #expect(try JSONDecoder().decode([TripNote].self, from: data) == [note])
    }

    @Test func keepsTicketsAndReservationsOffline() {
        #expect(DocumentCategory.ticket.isKeptOffline)
        #expect(DocumentCategory.reservation.isKeptOffline)
        #expect(!DocumentCategory.other.isKeptOffline)
        #expect(DocumentCategory.allCases.map(\.defaultIcon) == [.confirmationNumber, .bed, .info])
    }

    @Test(arguments: [
        ("4821#", true),
        ("sardynki2027", true),
        ("Zbiórka na Okęciu o 04:45", false),
        ("", false),
    ])
    func showsShortSingleWordNotesAsCodes(text: String, isCode: Bool) {
        let note = TripNote(id: "n", title: "t", text: text, pinned: true, author: nil, updatedAt: "2027-05-01T10:00:00.000Z")
        #expect(note.isCode == isCode)
    }

    @Test func formatsNoteAgeInPolish() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(NoteFormat.relative(now.addingTimeInterval(-20), now: now) == "przed chwilą")
        #expect(NoteFormat.relative(now.addingTimeInterval(-14 * 24 * 3600), now: now) == "2 tygodnie temu")
        #expect(NoteFormat.relative(nil, now: now) == nil)
    }
}
