import Foundation
import Testing
@testable import zmykamy_pl

struct LocalDateTests {
    @Test(arguments: ["2027-05", "12.05.2027", "", "jutro"])
    func rejectsMalformedDates(_ text: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LocalDate.self, from: Data("\"\(text)\"".utf8))
        }
    }

    @Test func roundTripsPaddedDates() throws {
        let date = LocalDate(year: 2027, month: 1, day: 2)
        let json = try #require(String(data: JSONEncoder().encode(date), encoding: .utf8))

        #expect(json == "\"2027-01-02\"")
        #expect(try JSONDecoder().decode(LocalDate.self, from: Data(json.utf8)) == date)
    }

    @Test func ordersChronologically() {
        let dates = [
            LocalDate(year: 2027, month: 1, day: 2),
            LocalDate(year: 2026, month: 12, day: 31),
            LocalDate(year: 2027, month: 1, day: 1),
        ]

        #expect(dates.sorted().map(\.day) == [31, 1, 2])
    }

    @Test func countsDaysAcrossMonthsAndYears() {
        let calendar = Calendar(identifier: .gregorian)

        #expect(LocalDate(year: 2026, month: 12, day: 29).days(until: LocalDate(year: 2027, month: 1, day: 2), calendar: calendar) == 4)
        #expect(LocalDate(year: 2028, month: 2, day: 28).days(until: LocalDate(year: 2028, month: 3, day: 1), calendar: calendar) == 2)
    }
}
