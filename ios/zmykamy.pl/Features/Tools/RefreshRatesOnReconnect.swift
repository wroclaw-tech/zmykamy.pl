import Network
import SwiftUI

extension View {
    /// Retry the visible quote after connectivity returns; cancel the monitor
    /// when its screen leaves the view hierarchy.
    func refreshRatesOnReconnect(_ refresh: @escaping @MainActor () async -> Void) -> some View {
        task {
            let monitor = NWPathMonitor()
            let updates = AsyncStream<Bool> { continuation in
                monitor.pathUpdateHandler = { path in continuation.yield(path.status == .satisfied) }
                continuation.onTermination = { _ in monitor.cancel() }
                monitor.start(queue: DispatchQueue(label: "pl.zmykamy.exchange-rates"))
            }
            var wasDisconnected = false
            for await connected in updates {
                guard !Task.isCancelled else { break }
                if connected && wasDisconnected { await refresh() }
                wasDisconnected = !connected
            }
        }
    }
}
