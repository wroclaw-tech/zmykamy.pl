import SwiftUI
import Vision
import VisionKit

/// Live camera scanner that reports the text of every QR code it recognizes.
struct QRScannerView: UIViewControllerRepresentable {
    let isScanning: Bool
    let onScan: (String) -> Void
    let onUnavailable: () -> Void

    /// False on the simulator, on devices without a supported camera, or when camera access is restricted.
    static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onScan = onScan
        context.coordinator.onUnavailable = onUnavailable
        if isScanning, !context.coordinator.hasFailed, !scanner.isScanning {
            do {
                try scanner.startScanning()
            } catch {
                context.coordinator.reportUnavailable()
            }
        } else if !isScanning, scanner.isScanning {
            scanner.stopScanning()
        }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        coordinator.isDismantled = true
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onUnavailable: onUnavailable)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onScan: (String) -> Void
        var onUnavailable: () -> Void
        private(set) var hasFailed = false
        var isDismantled = false

        init(onScan: @escaping (String) -> Void, onUnavailable: @escaping () -> Void) {
            self.onScan = onScan
            self.onUnavailable = onUnavailable
        }

        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            reportUnavailable()
        }

        func reportUnavailable() {
            guard !hasFailed, !isDismantled else { return }
            hasFailed = true
            // Startup can fail during a SwiftUI update; publish the error after that update finishes.
            Task { @MainActor [weak self] in
                guard let self, !isDismantled else { return }
                onUnavailable()
            }
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            addedItems.forEach(report)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            report(item)
        }

        private func report(_ item: RecognizedItem) {
            guard !hasFailed, !isDismantled else { return }
            guard case .barcode(let barcode) = item, let payload = barcode.payloadStringValue else { return }
            onScan(payload)
        }
    }
}
