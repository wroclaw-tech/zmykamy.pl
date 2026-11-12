import Foundation
import Testing
@testable import zmykamy_pl

struct APIClientTests {
    let backend = FakeBackend()

    @Test func sendsTheSessionTokenAndJSONBody() async throws {
        backend.on("POST", "trips/t1/tasks", returning: TripTask.fixture("k1"))

        let task: TripTask = try await backend.apiClient.send(
            "POST",
            "trips/t1/tasks",
            body: TripTaskRequest(title: "Kupić bilety", assigneeId: nil, dueDate: LocalDate(year: 2027, month: 5, day: 1)),
            token: "secret"
        )

        let request = try #require(backend.requests("POST", "trips/t1/tasks").first)
        #expect(task.id == "k1")
        #expect(request.header("Authorization") == "Bearer secret")
        #expect(request.json?["title"] as? String == "Kupić bilety")
        #expect(request.json?["dueDate"] as? String == "2027-05-01")
    }

    @Test(arguments: [
        (400, APIError.validation),
        (401, .unauthorized),
        (403, .forbidden),
        (404, .notFound),
        (409, .server(status: 409, code: "member_not_settled")),
        (500, .server(status: 500, code: "member_not_settled")),
    ])
    func turnsErrorResponsesIntoAPIErrors(status: Int, expected: APIError) async {
        backend.on("DELETE", "trips/t1/members/u2", status: status, json: #"{"error":{"code":"member_not_settled"}}"#)

        await #expect(throws: expected) {
            try await backend.apiClient.send("DELETE", "trips/t1/members/u2", token: "secret")
        }
    }

    @Test func reportsMissingConnectionAsNetworkError() async {
        backend.goOffline()

        await #expect(throws: APIError.network) {
            let _: [Trip] = try await backend.apiClient.send("GET", "trips", token: "secret")
        }
    }

    @Test func reportsUnexpectedResponseShapeAsServerError() async {
        backend.on("GET", "trips", json: #"{"unexpected":true}"#)

        await #expect(throws: APIError.server(status: 200, code: "DECODING_FAILED")) {
            let _: [Trip] = try await backend.apiClient.send("GET", "trips", token: "secret")
        }
    }

    @Test func uploadsToPresignedURLsWithoutTheSessionToken() async throws {
        let uploadURL = backend.baseURL.appending(path: "storage/cover.jpg")
        backend.on("PUT", "storage/cover.jpg")

        try await backend.apiClient.upload(Data([0xFF, 0xD8]), to: uploadURL, contentType: "image/jpeg")

        let request = try #require(backend.requests("PUT", "storage/cover.jpg").first)
        #expect(request.header("Content-Type") == "image/jpeg")
        #expect(request.header("Authorization") == nil)
    }

    @Test func explainsKnownServerErrorsToTheUser() {
        #expect(APIError.server(status: 409, code: "member_not_settled").localizedDescription.contains("rozliczyć saldo"))
        #expect(APIError.server(status: 409, code: "plan_points_out_of_range").localizedDescription.contains("punkty planu"))
        #expect(APIError.server(status: 500, code: nil).localizedDescription == "Coś poszło nie tak. Spróbuj ponownie za chwilę.")
    }
}
