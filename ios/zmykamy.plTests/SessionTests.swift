import Foundation
import Testing
@testable import zmykamy_pl

/// Signing in and out, and keeping the session alive across launches.
@MainActor
@Suite(.offlineCache)
struct SessionTests {
    let backend = FakeBackend()

    private static let sessionJSON = """
    {"session":{"id":"s1","expiresAt":"2027-01-01T00:00:00Z"},\
    "user":{"id":"u1","name":"Kuba Nowak","email":"kuba@zmykamy.pl","image":null}}
    """

    private static let signInJSON = """
    {"token":"body-token","user":{"id":"u1","name":"Kuba","email":"kuba@zmykamy.pl","image":null}}
    """

    @Test func signingInKeepsTheSessionForTheNextLaunch() async throws {
        backend.on("POST", "auth/sign-in/email", json: Self.signInJSON)
        let auth = backend.authStore()

        try await auth.signIn(email: "kuba@zmykamy.pl", password: "haslo1234")

        #expect(auth.user?.name == "Kuba")
        #expect(backend.keychain.load()?.token == "body-token")
    }

    @Test func prefersTheTokenTheServerRotatedInTheHeader() async throws {
        backend.on("POST", "auth/sign-in/email", headers: ["set-auth-token": "header-token"], json: Self.signInJSON)
        let auth = backend.authStore()

        try await auth.signIn(email: "kuba@zmykamy.pl", password: "haslo1234")

        #expect(try auth.currentToken() == "header-token")
    }

    @Test func wrongPasswordLeavesTheUserSignedOut() async {
        backend.on("POST", "auth/sign-in/email", status: 401, json: #"{"code":"INVALID_EMAIL_OR_PASSWORD"}"#)
        let auth = backend.authStore()

        await #expect(throws: AuthError.invalidCredentials) {
            try await auth.signIn(email: "kuba@zmykamy.pl", password: "zle")
        }
        #expect(auth.user == nil)
        #expect(backend.keychain.load() == nil)
    }

    @Test func signsUpWithTheChosenColorAndCurrentTerms() async throws {
        backend.on("POST", "auth/sign-up/email", json: Self.signInJSON)
        let auth = backend.authStore()

        try await auth.signUp(name: "Kuba", email: "kuba@zmykamy.pl", password: "haslo1234", themePalette: "mountains")

        let body = try #require(backend.requests("POST", "auth/sign-up/email").first?.json)
        #expect(body["themePalette"] as? String == "mountains")
        #expect(body["termsVersion"] as? String == AuthStore.currentTermsVersion)
        #expect(auth.user != nil)
    }

    @Test func opensSignedOutWithoutASavedSession() async {
        let auth = backend.authStore()

        await auth.restore()

        #expect(auth.state == .signedOut)
        #expect(backend.requests.isEmpty)
    }

    @Test func restoresTheSavedSessionWithFreshProfileData() async {
        backend.on("GET", "auth/get-session", json: Self.sessionJSON)
        let auth = backend.signedIn(as: .fixture(name: "Kuba"))

        await auth.restore()

        #expect(auth.user?.name == "Kuba Nowak")
    }

    @Test func staysSignedInWhenOffline() async {
        backend.goOffline()
        let auth = backend.signedIn(as: .fixture(name: "Kuba"))

        await auth.restore()

        #expect(auth.user?.name == "Kuba")
        #expect(backend.keychain.load() != nil)
    }

    @Test func signsOutWhenTheServerNoLongerKnowsTheSession() async {
        backend.on("GET", "auth/get-session", json: "null")
        let auth = backend.signedIn()

        await auth.restore()

        #expect(auth.state == .signedOut)
        #expect(backend.keychain.load() == nil)
    }

    @Test func signingOutForgetsTheSessionAndOfflineData() async {
        backend.on("POST", "auth/sign-out")
        OfflineCache.save([Trip.fixture()], as: "trips")
        let auth = backend.signedIn()

        await auth.signOut()

        #expect(auth.state == .signedOut)
        #expect(backend.keychain.load() == nil)
        #expect(OfflineCache.load([Trip].self, name: "trips") == nil)
        #expect(backend.requests("POST", "auth/sign-out").first?.header("Authorization") == "Bearer token-1")
    }

    @Test func signingOutWorksOffline() async {
        backend.goOffline()
        let auth = backend.signedIn()

        await auth.signOut()

        #expect(auth.state == .signedOut)
    }

    @Test func expiredSessionDuringAnAPICallSignsTheUserOut() async {
        backend.on("GET", "trips", status: 401)
        backend.on("POST", "auth/sign-out")
        let auth = backend.signedIn()
        let trips = TripsStore(auth: auth, client: backend.apiClient)

        await #expect(throws: APIError.unauthorized) {
            try await trips.load()
        }
        #expect(auth.state == .signedOut)
        #expect(backend.keychain.load() == nil)
    }

    @Test func recognizesThisDeviceAmongActiveSessions() throws {
        let auth = backend.signedIn(token: "abc.signature")
        let date = Date(timeIntervalSince1970: 0)
        let this = DeviceSession(id: "s1", token: "abc", createdAt: date, updatedAt: date, userAgent: nil, deviceName: nil, city: nil, countryCode: nil)
        let other = DeviceSession(id: "s2", token: "xyz", createdAt: date, updatedAt: date, userAgent: nil, deviceName: nil, city: nil, countryCode: nil)

        #expect(auth.isCurrent(this))
        #expect(!auth.isCurrent(other))
    }

    @Test func profileUpdatesSendOnlyChangedFieldsAndNullForCleared() async throws {
        backend.on("POST", "auth/update-user")
        backend.on("GET", "auth/get-session", json: Self.sessionJSON)
        let auth = backend.signedIn()

        try await auth.updateUser(UpdateUserRequest(firstName: "Jakub", iban: .some(nil)))

        let body = try #require(backend.requests("POST", "auth/update-user").first?.json)
        #expect(body["firstName"] as? String == "Jakub")
        #expect(body["iban"] is NSNull)
        #expect(body["phone"] == nil)
        #expect(UpdateUserRequest().isEmpty)
    }
}

@MainActor
struct UserCalendarTests {
    @Test(arguments: [("sunday", 1), ("monday", 2), (nil, 2)] as [(String?, Int)])
    func startsTheWeekOnThePreferredDay(weekStart: String?, firstWeekday: Int) {
        var user = AuthUser.fixture()
        user.weekStart = weekStart

        #expect(user.calendar.firstWeekday == firstWeekday)
    }
}
