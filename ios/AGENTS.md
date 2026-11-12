# zmykamy.pl iOS app

SwiftUI app (iOS 26.6+, Swift 6, Xcode 27). Code lives in `zmykamy.pl/`:

- `App/`: entry point and root view
- `Core/`: API and auth clients, session keychain storage, offline cache
- `Features/<Feature>/`: models (`*Models.swift`), an `@Observable` store (`*Store.swift`) talking to the API, and views
- `DesignSystem/`: theme, typography, shared components

The app target defaults to `@MainActor` isolation; models are explicitly `nonisolated`.

## Building and testing

Use `scripts/xcode.sh`, the same script CI runs (`.github/workflows/ios.yml`). It picks the newest available iPhone simulator. Set `SIMULATOR=<name or UDID>` to override.

```sh
scripts/xcode.sh unit      # unit tests, ~1 min after the first build
scripts/xcode.sh ui        # UI tests, a few minutes
scripts/xcode.sh test      # both
scripts/xcode.sh release   # unsigned Release build for devices

scripts/xcode.sh unit -only-testing:zmykamy.plTests/PollsStoreTests   # one suite
```

Results land in `build/results/*.xcresult` (open in Xcode to see failures and screenshots).

CI runs unit tests, UI tests and the Release build on every PR that touches `ios/`. All three must pass. Run at least `unit` and `release` before pushing: Release catches code that only compiles in Debug (e.g. previews using `#if DEBUG` fixtures, which must be wrapped in `#if DEBUG` too).

## Writing tests

### What to test

Test what a user or the backend would notice, not how the code is put together. A good test survives a refactor that keeps behaviour the same, and fails when behaviour changes. Ask: "if this test fails, is something actually broken for someone?"

Cover:

- **API contract**: decoding real response JSON (paste it raw, as the backend sends it) and the JSON we send, especially `null` vs. omitted fields (`String??`, `LocalDate??` in update requests clear a field when `.some(nil)`).
- **Store behaviour against the API**: what the store shows after a load, create, update or delete; ordering (tasks by due date, plan points by time, pinned notes first); state left unchanged when a request fails; offline fallback to the cache.
- **Session handling**: sign in/up/out, restoring a session on launch, staying signed in offline, signing out on `401`.
- **Domain rules and calculations**: money splitting and parsing, settlements, trip phases and dates (time zones, DST, month/year boundaries), permissions (`canEdit`, `canManage`), Polish plurals and formatting.
- **Error handling**: which `APIError`/`AuthError` the user ends up with, and that known server codes get a helpful message.
- **Critical UI flows**: only in UI tests, and only flows that work without a backend (onboarding, form validation).

Don't test:

- SwiftUI layout, colors, fonts, or static copy. Previews and manual checks cover those.
- Private helpers on their own. Test them through the public behaviour that uses them.
- That a store "called the client". Assert on what the store exposes and what reached the backend.
- Trivial code (enum raw values, memberwise inits, computed properties that just forward).

When you fix a bug, first write a test that reproduces it.

### How to write them

- Use **Swift Testing** (`import Testing`, `@Test`, `#expect`, `#require`) for unit tests. Use XCTest only for UI tests (`XCUIApplication`).
- Name tests as a statement of behaviour: `showsLastSeenTripsWhenOffline`, `rejoiningATripDoesNotDuplicateIt`, not `testLoad2`.
- Structure each test as arrange / act / assert, separated by blank lines, with one behaviour per test. Several `#expect`s are fine when they describe the same behaviour.
- Use `#require` to unwrap values the rest of the test depends on. Use `#expect(throws: SomeError.case)` for failures.
- Use parameterized tests (`@Test(arguments:)`) for tables of inputs and outputs instead of copy-pasted tests.
- Keep tests deterministic. Pass a fixed `Calendar`/time zone and a fixed "today" or "now" instead of using `.current` or `Date()`. Don't sleep.
- Mark suites that touch stores, `AuthUser`, or other main-actor code `@MainActor`.
- Suites run in parallel. Don't share mutable state between tests.

### Test helpers (`zmykamy.plTests/Support/`)

- **`FakeBackend`** replaces the network and nothing else. Stub responses with `backend.on("GET", "trips", returning: [...])` or raw `json:`. Simulate no connection with `offline(...)` or `goOffline()`. Inspect what was sent with `backend.requests("POST", "trips")` (`header(_:)`, `json`). Build real objects from it: `backend.signedIn()` gives an `AuthStore` with a session in a keychain entry private to the test, `backend.api(auth)` gives an `AuthorizedAPI`, and `backend.apiClient` / `authClient` give clients. Unstubbed requests get a `404`.
- **`.offlineCache` trait**: `OfflineCache` is one directory shared by the whole app, and signing out wipes it. Add `.offlineCache` to every suite or test that touches it, directly or through a store's offline fallback or sign-out. It runs those tests one at a time on an empty cache.
- **`Fixtures.swift`**: `Trip.fixture()`, `TripTask.fixture("id", due:)`, etc. Pass only the fields the test is about. Add a fixture when a model is needed in more than one suite.

Example:

```swift
@MainActor
struct TasksStoreTests {
    let backend = FakeBackend()
    let trip = Trip.fixture()

    @Test func keepsTheTaskWhenDeletingFails() async throws {
        backend.on("GET", "trips/t1/tasks", returning: [TripTask.fixture("tickets")])
        backend.offline("DELETE", "trips/t1/tasks/tickets")
        let tasks = TasksStore(api: backend.api(backend.signedIn()))
        try await tasks.load(trip)

        await #expect(throws: APIError.network) {
            try await tasks.delete(.fixture("tickets"), from: trip)
        }

        #expect(tasks.tasks(for: trip)?.map(\.id) == ["tickets"])
    }
}
```

### Making code testable

Inject dependencies through initializers with production defaults, as `APIClient(baseURL:session:)`, `AuthClient(baseURL:configuration:)` and `SessionStore(service:)` already do. Pass `calendar`/`now` into date logic. Don't add protocols or mocks for our own types just for tests. Prefer real collaborators and fake only the network.

### UI tests

UI tests are slow, so keep them few. They cover critical paths and should not repeat what unit tests already check. Launch with `-resetState` (handled in `ZmykamyApp`, Debug only) to start from a fresh install. Find elements by their user-visible label or accessibility label. Wait with `waitForExistence(timeout:)`, never `sleep`.

### Checklist for a new feature

1. Decoding tests with real JSON for each new response, plus encoding tests for requests with nullable fields.
2. Store tests through `FakeBackend`: load, each mutation, ordering, failure leaves state intact, offline fallback if the store caches.
3. Unit tests for any rules, calculations, or formatting in the models.
4. A UI test only if the feature adds a critical flow that works without a backend.
5. `scripts/xcode.sh unit && scripts/xcode.sh release` pass locally.
