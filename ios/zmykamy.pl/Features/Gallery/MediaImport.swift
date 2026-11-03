import AVFoundation
import CoreTransferable
import ImageIO
import UIKit
import UniformTypeIdentifiers

nonisolated struct PreparedMedia: Sendable {
    let kind: MediaKind
    let contentType: String
    let fileURL: URL
    let thumbnail: Data
    let width: Int
    let height: Int
    let durationSeconds: Double?
    let takenAt: Date
}

nonisolated struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let destination = FileManager.default.temporaryDirectory
                .appending(path: "\(UUID().uuidString).\(received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension)")
            try FileManager.default.copyItem(at: received.file, to: destination)
            return PickedMovie(url: destination)
        }
    }
}

nonisolated enum MediaImport {
    private static let maxPhotoDimension: CGFloat = 4096
    private static let thumbnailDimension: CGFloat = 640

    @concurrent
    static func photo(from data: Data) async -> PreparedMedia? {
        guard let image = UIImage(data: data) else { return nil }
        return photo(image, takenAt: exifDate(in: data) ?? .now)
    }

    @concurrent
    static func photo(from image: UIImage) async -> PreparedMedia? {
        photo(image, takenAt: .now)
    }

    @concurrent
    static func video(at url: URL) async -> PreparedMedia? {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let (naturalSize, transform) = try? await track.load(.naturalSize, .preferredTransform) else {
            return nil
        }
        let size = naturalSize.applying(transform)
        let duration = (try? await asset.load(.duration)).map(CMTimeGetSeconds)
        let creationDate = try? await asset.load(.creationDate)?.load(.dateValue)

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: thumbnailDimension, height: thumbnailDimension)
        guard let frame = try? await generator.image(at: .zero).image,
              let thumbnail = UIImage(cgImage: frame).jpegData(compressionQuality: 0.75) else {
            return nil
        }

        let isMP4 = ["mp4", "m4v"].contains(url.pathExtension.lowercased())
        return PreparedMedia(
            kind: .video,
            contentType: isMP4 ? "video/mp4" : "video/quicktime",
            fileURL: url,
            thumbnail: thumbnail,
            width: Int(abs(size.width)),
            height: Int(abs(size.height)),
            durationSeconds: duration.flatMap { $0.isFinite ? $0 : nil },
            takenAt: creationDate ?? .now
        )
    }

    static func discard(_ media: PreparedMedia) {
        try? FileManager.default.removeItem(at: media.fileURL)
    }

    private static func photo(_ image: UIImage, takenAt: Date) -> PreparedMedia? {
        let original = resized(image, maxDimension: maxPhotoDimension)
        guard let data = original.jpegData(compressionQuality: 0.85),
              let thumbnail = resized(image, maxDimension: thumbnailDimension).jpegData(compressionQuality: 0.75) else {
            return nil
        }
        let fileURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).jpg")
        do {
            try data.write(to: fileURL)
        } catch {
            return nil
        }
        return PreparedMedia(
            kind: .photo,
            contentType: "image/jpeg",
            fileURL: fileURL,
            thumbnail: thumbnail,
            width: Int(original.size.width),
            height: Int(original.size.height),
            durationSeconds: nil,
            takenAt: takenAt
        )
    }

    private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func exifDate(in data: Data) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let raw = exif[kCGImagePropertyExifDateTimeOriginal] as? String else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        if let offset = exif[kCGImagePropertyExifOffsetTimeOriginal] as? String {
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ssxxx"
            return formatter.date(from: raw + offset)
        }
        return formatter.date(from: raw)
    }
}
