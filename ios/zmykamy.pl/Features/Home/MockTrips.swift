import SwiftUI

struct TripParticipant: Identifiable {
    let id = UUID()
    let initial: String
    let color: Color?
}

struct UpcomingTrip {
    let title: String
    let subtitle: String
    let status: String
    let image: ImageResource
    let participants: [TripParticipant]
}

struct TripSummary: Identifiable {
    enum Badge {
        case countdown(String)
        case settled
    }

    let id = UUID()
    let title: String
    let subtitle: String
    let badge: Badge
    let thumbnail: (Theme) -> [Color]
}

enum MockTrips {
    static let current = UpcomingTrip(
        title: "Lizbona",
        subtitle: "12–18 maja 2027 · Portugalia",
        status: "Trwa · dzień 3 z 7",
        image: .onboardingLisbon,
        participants: [
            TripParticipant(initial: "K", color: nil),
            TripParticipant(initial: "O", color: .avatar2),
            TripParticipant(initial: "M", color: .statusSuccess),
            TripParticipant(initial: "Z", color: .avatar4),
            TripParticipant(initial: "B", color: .avatar5),
            TripParticipant(initial: "N", color: .avatar6),
        ]
    )

    static let planned = [
        TripSummary(
            title: "Sylwek w Zakopanem",
            subtitle: "29 gru – 2 sty · 8 os.",
            badge: .countdown("za 229 dni"),
            thumbnail: { [$0.accentTint, $0.accentStrong] }
        ),
    ]

    static let past = [
        TripSummary(
            title: "Mazury",
            subtitle: "8–15 sie 2026 · 8 os.",
            badge: .settled,
            thumbnail: { [$0.accentTint, $0.accent] }
        ),
        TripSummary(
            title: "Berlin",
            subtitle: "14–16 mar 2026 · 3 os.",
            badge: .settled,
            thumbnail: { [$0.accent, $0.accentStrong] }
        ),
    ]
}
