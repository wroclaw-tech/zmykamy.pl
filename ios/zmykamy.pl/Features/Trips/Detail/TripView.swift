import SwiftUI

struct CloseTripButton: ToolbarContent {
    @Environment(\.dismiss) private var dismiss

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Wróć do listy wyjazdów", image: .arrowBackIosNew) { dismiss() }
        }
    }
}

/// A trip opened from the list, with its own navigation in every tab.
struct TripView: View {
    let tripID: Trip.ID
    let user: AuthUser
    @Environment(TripsStore.self) private var trips
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        if let trip = trips.trip(id: tripID) {
            TabView {
                Tab("Przegląd", image: "tab_home") {
                    NavigationStack {
                        TripOverviewView(trip: trip, user: user)
                            .toolbar { CloseTripButton() }
                    }
                }
                Tab("Plan", image: "tab_calendar_month") {
                    PlanView(trip: trip, user: user)
                }
                Tab("Wydatki", image: "tab_payments") {
                    ExpensesView(trip: trip, user: user)
                }
                Tab("Galeria", image: "tab_photo_library") {
                    GalleryView(trip: trip, user: user)
                }
                Tab("Ekipa", image: "tab_group") {
                    NavigationStack {
                        TeamView(trip: trip, user: user)
                            .toolbar { CloseTripButton() }
                    }
                }
            }
            .tint(theme.accent)
        } else {
            theme.background
                .ignoresSafeArea()
                .onAppear { dismiss() }
        }
    }
}
