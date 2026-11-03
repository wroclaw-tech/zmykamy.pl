import Foundation

extension AuthUser {
    /// Gregorian calendar with the user's preferred first weekday.
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "pl_PL")
        calendar.firstWeekday = weekStart == "sunday" ? 1 : 2
        return calendar
    }
}
