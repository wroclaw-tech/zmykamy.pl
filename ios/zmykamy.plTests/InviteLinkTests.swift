import Foundation
import Testing
@testable import zmykamy_pl

struct InviteLinkTests {
    @Test(arguments: [
        "https://zmykamy.pl/j/LIZ-6K2PX9QM",
        "https://www.zmykamy.pl/j/LIZ-6K2PX9QM",
        "https://ZMYKAMY.PL/j/LIZ-6K2PX9QM",
        "https://zmykamy.pl/j/LIZ-6K2PX9QM/",
        "https://zmykamy.pl/j/LIZ-6K2PX9QM?utm_source=qr",
        "  https://zmykamy.pl/j/LIZ-6K2PX9QM\n",
    ])
    func recognizesInviteLinks(_ text: String) {
        #expect(InviteLink.slug(from: text) == "LIZ-6K2PX9QM")
    }

    @Test func recognizesLinksFromTheAPIHost() throws {
        let host = try #require(APIConfiguration.baseURL.host())
        let scheme = try #require(APIConfiguration.baseURL.scheme)
        let port = APIConfiguration.baseURL.port.map { ":\($0)" } ?? ""

        #expect(InviteLink.slug(from: "\(scheme)://\(host)\(port)/j/Z-ABCD2345") == "Z-ABCD2345")
    }

    @Test(arguments: [
        "",
        "Zmykamy",
        "LIZ-6K2PX9QM",
        "WIFI:T:WPA;S:Hotel;P:haslo123;;",
        "https://example.com/j/LIZ-6K2PX9QM",
        "https://zmykamy.pl.example.com/j/LIZ-6K2PX9QM",
        "https://example.com/?next=https://zmykamy.pl/j/LIZ-6K2PX9QM",
        "ftp://zmykamy.pl/j/LIZ-6K2PX9QM",
        "zmykamy.pl/j/LIZ-6K2PX9QM",
        "https://zmykamy.pl/",
        "https://zmykamy.pl/j",
        "https://zmykamy.pl/trips/LIZ-6K2PX9QM",
        "https://zmykamy.pl/j/LIZ-6K2PX9QM/extra",
        "https://zmykamy.pl/j/LIZ6K2PX9QM",
        "https://zmykamy.pl/j/LIZA-6K2PX9QM",
        "https://zmykamy.pl/j/LIZ-6K2PX9Q",
        "https://zmykamy.pl/j/LIZ-6K2PX9QM%20",
    ])
    func ignoresOtherCodes(_ text: String) {
        #expect(InviteLink.slug(from: text) == nil)
    }
}
