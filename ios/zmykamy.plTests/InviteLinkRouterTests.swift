import Foundation
import Testing
@testable import zmykamy_pl

@MainActor
struct InviteLinkRouterTests {
    @Test func opensAnInviteLink() {
        let router = InviteLinkRouter()

        router.open(URL(string: "https://zmykamy.pl/j/LIZ-6K2PX9QM")!)

        #expect(router.pending == PendingInvite(code: "LIZ-6K2PX9QM"))
    }

    @Test(arguments: [
        "https://zmykamy.pl/",
        "https://zmykamy.pl/j",
        "https://zmykamy.pl/trips/LIZ-6K2PX9QM",
        "https://zmykamy.pl/j/LIZ-6K2PX9QM/extra",
        "https://example.com/j/LIZ-6K2PX9QM",
    ])
    func ignoresOtherLinks(_ link: String) {
        let router = InviteLinkRouter()

        router.open(URL(string: link)!)

        #expect(router.pending == nil)
    }
}

struct BalanceFormatTests {
    @Test func showsTheSignOfNonZeroBalances() {
        let positive = BalanceFormat.string(minorUnits: 335_867, currency: "PLN")
        let negative = BalanceFormat.string(minorUnits: -83_733, currency: "PLN")

        #expect(positive.hasPrefix("+"))
        #expect(positive.contains("3") && positive.contains("358,67"))
        #expect(negative.contains("837,33"))
        #expect(negative.hasPrefix("-") || negative.hasPrefix("−"))
    }

    @Test func leavesZeroUnsigned() {
        let zero = BalanceFormat.string(minorUnits: 0, currency: "PLN")

        #expect(zero.contains("0,00"))
        #expect(!zero.hasPrefix("+") && !zero.hasPrefix("-"))
    }
}
