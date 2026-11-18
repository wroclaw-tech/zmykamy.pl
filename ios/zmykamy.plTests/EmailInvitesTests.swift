import Foundation
import Testing
@testable import zmykamy_pl

@MainActor
struct EmailInvitesStoreTests {
    let backend = FakeBackend()
    let trip = Trip.fixture()

    private func store() -> TripsStore {
        TripsStore(auth: backend.signedIn(), client: backend.apiClient)
    }

    @Test func sendsTheAddressesAndReportsWhatHappened() async throws {
        backend.on("POST", "trips/t1/email-invites", status: 201, json: """
        {"invites":[{"id":"i1","email":"tomek@example.com","status":"sent",\
        "sentAt":"2026-11-18T15:38:59.217Z","joinedAt":null}],\
        "alreadyMembers":["kuba@example.com"],"alreadyInvited":["zuza@example.com"],"failed":[]}
        """)

        let result = try await store().sendEmailInvites(to: ["tomek@example.com", "kuba@example.com"], for: trip)

        #expect(result.invites.map(\.email) == ["tomek@example.com"])
        #expect(result.invites.first?.status == .sent)
        #expect(result.alreadyMembers == ["kuba@example.com"])
        #expect(result.alreadyInvited == ["zuza@example.com"])
        let sent = try #require(backend.requests("POST", "trips/t1/email-invites").first?.json)
        #expect(sent["emails"] as? [String] == ["tomek@example.com", "kuba@example.com"])
    }

    @Test func decodesJoinedInvitations() async throws {
        backend.on("GET", "trips/t1/email-invites", json: """
        [{"id":"i1","email":"ola@example.com","status":"joined",\
        "sentAt":"2026-11-16T10:00:00.000Z","joinedAt":"2026-11-17T08:30:00.000Z"},\
        {"id":"i2","email":"tomek@example.com","status":"sent",\
        "sentAt":"2026-11-18T15:38:59.217Z","joinedAt":null}]
        """)

        let invites = try await store().emailInvites(for: trip)

        #expect(invites.map(\.status) == [.joined, .sent])
        #expect(invites.first?.joinedAt != nil)
    }

    @Test func showsPendingInvitationsUntilTheTripIsJoined() async throws {
        backend.on("GET", "email-invites", json: """
        [{"id":"i1","code":"LIZ-6K2PX9QM","trip":{"id":"t1","name":"Lizbona",\
        "destination":{"name":"Lizbona","country":"Portugalia"},\
        "startDate":"2027-05-12","endDate":"2027-05-18"},\
        "inviterName":"Kuba","sentAt":"2026-11-18T15:38:59.217Z"}]
        """)
        backend.on("POST", "invites/LIZ-6K2PX9QM/join", returning: Trip.fixture(id: "t1"))
        let trips = store()
        try await trips.loadPendingEmailInvites()
        #expect(trips.pendingEmailInvites.map(\.code) == ["LIZ-6K2PX9QM"])
        #expect(trips.pendingEmailInvites.first?.inviterName == "Kuba")

        _ = try await trips.join(inviteCode: "LIZ-6K2PX9QM")

        #expect(trips.pendingEmailInvites.isEmpty)
    }

    @Test func explainsTheResendCooldown() async {
        backend.on("POST", "trips/t1/email-invites/i1/resend", status: 429, headers: ["Retry-After": "600"], json: """
        {"error":{"code":"rate_limited","message":"Too many requests, try again later"}}
        """)
        let invite = EmailInvite(id: "i1", email: "tomek@example.com", status: .sent, sentAt: .now, joinedAt: nil)

        await #expect(throws: APIError.server(status: 429, code: "rate_limited")) {
            try await store().resend(invite, for: trip)
        }
        #expect(APIError.server(status: 429, code: "rate_limited").localizedDescription.contains("Spróbuj ponownie później"))
    }
}

struct EmailAddressesTests {
    @Test func splitsNormalizesAndDedupes() {
        let parsed = EmailAddresses.parse(" Ola@Example.com, tomek@example.com;\nola@example.com  zuza@example.pl ")

        #expect(parsed.valid == ["ola@example.com", "tomek@example.com", "zuza@example.pl"])
        #expect(parsed.invalid.isEmpty)
    }

    @Test(arguments: ["ola", "ola@", "@example.com", "ola@example", "ola@@example.com"])
    func rejectsInvalidAddresses(text: String) {
        #expect(EmailAddresses.parse(text).invalid == [text])
    }

    @Test(arguments: [
        (1, "Wysłano 1 zaproszenie."),
        (3, "Wysłano 3 zaproszenia."),
        (5, "Wysłano 5 zaproszeń."),
    ])
    func summarizesSentInvitations(count: Int, expected: String) {
        let invites = (0..<count).map {
            EmailInvite(id: "\($0)", email: "guest\($0)@example.com", status: .sent, sentAt: .now, joinedAt: nil)
        }
        let result = EmailInviteResult(invites: invites, alreadyMembers: [], alreadyInvited: [], failed: [])

        #expect(result.summary == expected)
    }

    @Test func listsSkippedAndFailedAddresses() {
        let result = EmailInviteResult(
            invites: [],
            alreadyMembers: ["kuba@example.com"],
            alreadyInvited: ["ola@example.com", "zuza@example.com"],
            failed: ["bounce@example.com"]
        )

        #expect(result.summary == """
        Już w ekipie: kuba@example.com.
        Już zaproszeni: ola@example.com, zuza@example.com.
        Nie udało się wysłać: bounce@example.com.
        """)
    }
}
