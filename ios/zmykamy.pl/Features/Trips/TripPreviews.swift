#if DEBUG
import Foundation

extension AuthUser {
    static let preview = AuthUser(
        id: "kuba",
        name: "Kuba",
        email: "kuba@zmykamy.pl",
        image: nil,
        themePalette: "ocean",
        termsVersion: nil,
        termsAcceptedAt: .now
    )
}

extension Trip {
    static let preview: Trip = {
        let today = LocalDate(.now)
        let names = ["Kuba", "Bartek", "Zuza", "Natalia", "Michał", "Ola"]
        return Trip(
            id: "lizbona",
            name: "Lizbona",
            destination: TripDestination(name: "Lizbona", country: "Portugalia", latitude: nil, longitude: nil),
            startDate: today.adding(days: 12),
            endDate: today.adding(days: 18),
            currency: "EUR",
            coverUrl: nil,
            myRole: .organizer,
            members: names.map { name in
                TripMember(
                    userId: name.lowercased(),
                    name: name,
                    image: nil,
                    role: name == "Kuba" ? .organizer : .participant,
                    balance: 0
                )
            }
        )
    }()
}
#endif
