import Foundation
import Observation

nonisolated struct ExchangeRate: Codable, Equatable, Sendable {
    let from: String
    let to: String
    let rate: Double
    let effectiveDate: LocalDate
    let table: String?

    var dateLabel: String {
        String(format: "%02d.%02d.%04d", effectiveDate.day, effectiveDate.month, effectiveDate.year)
    }

    var attribution: String {
        from == to ? "Ta sama waluta" : "Kurs średni NBP z \(dateLabel)"
    }
}

nonisolated struct RateQuote: Equatable, Sendable {
    let value: ExchangeRate
    let isOffline: Bool
}

@Observable
final class ExchangeRatesStore {
    private let api: AuthorizedAPI

    init(api: AuthorizedAPI) { self.api = api }

    // Cache by requested date as well as currency pair: an expense must never
    // accidentally reuse today's rate for a different payment day.
    func quote(from: String, to: String, on date: LocalDate, in trip: Trip, allowStale: Bool = false) async throws(APIError) -> RateQuote {
        if from == to {
            return RateQuote(value: ExchangeRate(from: from, to: to, rate: 1, effectiveDate: date, table: nil), isOffline: false)
        }
        if to == trip.currency { return try await tripRate(from: from, on: date, in: trip, allowStale: allowStale) }
        let source = try await tripRate(from: from, on: date, in: trip, allowStale: allowStale)
        let target = try await tripRate(from: to, on: date, in: trip, allowStale: allowStale)
        let tables = Set([source.value.table, target.value.table].compactMap { $0 }.flatMap { $0.split(separator: "/").map(String.init) })
        let value = ExchangeRate(
            from: from, to: to, rate: source.value.rate / target.value.rate,
            effectiveDate: min(source.value.effectiveDate, target.value.effectiveDate),
            table: tables.isEmpty ? nil : tables.sorted().joined(separator: "/")
        )
        return RateQuote(value: value, isOffline: source.isOffline || target.isOffline)
    }

    private func tripRate(from: String, on date: LocalDate, in trip: Trip, allowStale: Bool = false) async throws(APIError) -> RateQuote {
        if from == trip.currency {
            return RateQuote(value: ExchangeRate(from: from, to: from, rate: 1, effectiveDate: date, table: nil), isOffline: false)
        }
        let latestKey = "rate-latest-\(trip.id)-\(from)-\(trip.currency)"
        let key = "rate-\(trip.id)-\(from)-\(trip.currency)-\(date.rawValue)"
        do throws(APIError) {
            let value: ExchangeRate = try await api.call { (client, token) throws(APIError) in
                try await client.send("GET", "trips/\(trip.id)/exchange-rate", query: [
                    URLQueryItem(name: "currency", value: from), URLQueryItem(name: "date", value: date.rawValue),
                ], token: token)
            }
            guard value.from == from, value.to == trip.currency, value.rate.isFinite, value.rate > 0 else {
                throw APIError.server(status: 200, code: "DECODING_FAILED")
            }
            OfflineCache.save(value, as: key)
            let latest = OfflineCache.load(ExchangeRate.self, name: latestKey)
            if latest == nil || latest!.effectiveDate <= value.effectiveDate {
                OfflineCache.save(value, as: latestKey)
            }
            return RateQuote(value: value, isOffline: false)
        } catch {
            guard error == .network || error == .server(status: 502, code: "rate_unavailable"),
                  let value = OfflineCache.load(ExchangeRate.self, name: key)
                    ?? (allowStale ? OfflineCache.load(ExchangeRate.self, name: latestKey) : nil) else { throw error }
            return RateQuote(value: value, isOffline: true)
        }
    }
}
