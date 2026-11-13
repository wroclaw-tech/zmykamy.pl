#if DEBUG
import SwiftUI

/// A deterministic, local-only entry point for previews and UI smoke tests.
/// It has its own keychain entry and never sends requests to the real backend.
struct ToolsPreview: View {
    @State private var trips: TripsStore
    @State private var expenses: ExpensesStore
    @State private var documents: DocumentsStore
    private let trip: Trip

    init() {
        let template = Trip.preview
        trip = Trip(id: template.id, name: template.name, destination: template.destination,
                    startDate: template.startDate, endDate: template.endDate, currency: "PLN",
                    coverUrl: nil, myRole: .organizer, members: template.members)
        let session = SessionStore(service: "pl.zmykamy.tools-preview")
        session.save(StoredSession(token: "preview-only", user: .preview))
        let auth = AuthStore(store: session)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ToolsPreviewProtocol.self]
        let client = APIClient(baseURL: URL(string: "https://tools-preview.invalid")!, session: URLSession(configuration: configuration))
        let trips = TripsStore(auth: auth, client: client)
        _trips = State(initialValue: trips)
        _expenses = State(initialValue: ExpensesStore(api: trips.api, trips: trips))
        _documents = State(initialValue: DocumentsStore(api: trips.api))
    }

    var body: some View {
        NavigationStack { ToolsView(trip: trip, user: .preview) }
            .environment(trips).environment(expenses).environment(documents)
            .environment(PackingStore(api: trips.api))
            .environment(TasksStore(api: trips.api))
            .environment(PollsStore(api: trips.api))
            .environment(\.theme, VacationClimate.ocean.theme)
            .tint(VacationClimate.ocean.theme.accent)
    }
}

private nonisolated final class ToolsPreviewProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "tools-preview.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        let url = request.url!
        let json: String
        switch url.lastPathComponent {
        case "exchange-rate":
            let currency = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "currency" }?.value ?? "EUR"
            let rate = currency == "EUR" ? 4.27 : currency == "USD" ? 4.0 : 1.0
            json = """
            {"from":"\(currency)","to":"PLN","rate":\(rate),"effectiveDate":"2027-05-13","table":"A"}
            """
        case "lizbona":
            json = #"{"progress":{"packing":{"mine":{"packedCount":8,"totalCount":10},"shared":{"packedCount":0,"totalCount":0}},"tasks":{"doneCount":5,"totalCount":9},"polls":{"openCount":1,"awaitingMyVoteCount":1}}}"#
        case "documents": json = #"{"documents":[]}"#
        case "notes": json = #"{"notes":[]}"#
        case "settlement": json = #"{"balances":[],"transfers":[],"payments":[],"naiveTransferCount":0}"#
        default: json = "{}"
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

#Preview { ToolsPreview() }
#endif
