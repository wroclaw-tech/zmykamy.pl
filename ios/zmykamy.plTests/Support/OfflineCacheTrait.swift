import Testing
@testable import zmykamy_pl

/// Gives each test exclusive use of the on-disk `OfflineCache`, starting and ending empty.
///
/// The cache is a single directory shared by the whole app (and signing out wipes it), so
/// tests that read or write it, directly or through a store, would race when run in parallel.
/// Add `.offlineCache` to those tests or their suite.
struct OfflineCacheTrait: SuiteTrait, TestTrait, TestScoping {
    var isRecursive: Bool { true }

    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @concurrent @Sendable () async throws -> Void
    ) async throws {
        // Suites only pass the trait on to their tests; locking here too would deadlock.
        guard testCase != nil else { return try await function() }
        try await Self.lock.run {
            OfflineCache.clear()
            defer { OfflineCache.clear() }
            try await function()
        }
    }

    private static let lock = AsyncLock()
}

extension Trait where Self == OfflineCacheTrait {
    static var offlineCache: Self { Self() }
}

private actor AsyncLock {
    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func run(_ body: @concurrent @Sendable () async throws -> Void) async throws {
        await lock()
        do {
            try await body()
        } catch {
            unlock()
            throw error
        }
        unlock()
    }

    private func lock() async {
        guard isLocked else {
            isLocked = true
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func unlock() {
        if waiters.isEmpty {
            isLocked = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}
