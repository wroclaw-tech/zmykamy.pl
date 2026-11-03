import Foundation

nonisolated enum BalanceFormat {
    private static let locale = Locale(identifier: "pl_PL")

    /// Signed amount in the trip currency, e.g. `+3 358,67 zł`; zero has no sign.
    static func string(minorUnits: Int, currency: String) -> String {
        (Decimal(minorUnits) / 100).formatted(
            .currency(code: currency)
                .locale(locale)
                .sign(strategy: .always(showZero: false))
        )
    }
}
