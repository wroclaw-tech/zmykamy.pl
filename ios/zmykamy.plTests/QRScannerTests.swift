import Testing
@testable import zmykamy_pl

@MainActor
struct QRScannerTests {
    @Test func reportsFailureOnceAndDefersTheCallback() async {
        let (notifications, continuation) = AsyncStream<Void>.makeStream()
        var callbackCount = 0
        let coordinator = QRScannerView.Coordinator(onScan: { _ in }, onUnavailable: {
            callbackCount += 1
            continuation.yield(())
        })

        coordinator.reportUnavailable()
        coordinator.reportUnavailable()

        // A startup failure must not mutate view state during updateUIViewController.
        #expect(callbackCount == 0)
        var iterator = notifications.makeAsyncIterator()
        _ = await iterator.next()
        #expect(callbackCount == 1)
        #expect(coordinator.hasFailed)
        continuation.finish()
    }

    @Test func ignoresFailuresAfterDismantling() {
        let coordinator = QRScannerView.Coordinator(onScan: { _ in }, onUnavailable: {
            Issue.record("A dismissed scanner must not report an error")
        })
        coordinator.isDismantled = true

        coordinator.reportUnavailable()

        #expect(!coordinator.hasFailed)
    }
}
