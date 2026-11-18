import Testing
import UIKit
@testable import zmykamy_pl

@MainActor
struct QRImageReaderTests {
    @Test func readsTheInviteLinkFromAnImageOfItsQRCode() throws {
        let link = "https://zmykamy.pl/j/LIZ-6K2PX9QM"
        let code = try #require(QRCode.image(for: link))
        let size = CGSize(width: code.size.width + 160, height: code.size.height + 160)
        let image = try #require(UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            code.draw(at: CGPoint(x: 80, y: 80))
        }.pngData())

        let payloads = QRImageReader.payloads(in: image)

        #expect(payloads == [link])
    }

    @Test func findsNothingInAnImageWithoutACode() throws {
        let blank = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        }
        let image = try #require(blank.pngData())

        let payloads = QRImageReader.payloads(in: image)

        #expect(payloads.isEmpty)
    }

    @Test func findsNothingInDataThatIsNotAnImage() {
        let payloads = QRImageReader.payloads(in: Data("not an image".utf8))

        #expect(payloads.isEmpty)
    }
}
