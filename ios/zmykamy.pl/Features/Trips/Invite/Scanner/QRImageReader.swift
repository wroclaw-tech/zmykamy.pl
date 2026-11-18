import CoreImage

/// Reads QR codes from a still image, such as a screenshot or a photo picked from the library.
nonisolated enum QRImageReader {
    /// The text of every QR code found in the image; empty when there is none or the data isn't an image.
    static func payloads(in imageData: Data) -> [String] {
        guard let image = CIImage(data: imageData, options: [.applyOrientationProperty: true]),
              let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        else { return [] }
        return detector.features(in: image)
            .compactMap { ($0 as? CIQRCodeFeature)?.messageString }
    }
}
