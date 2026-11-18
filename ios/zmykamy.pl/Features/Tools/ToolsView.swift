import SwiftUI

struct ToolsView: View {
    let trip: Trip
    let user: AuthUser
    @Environment(TripsStore.self) private var trips
    @Environment(DocumentsStore.self) private var documents
    @Environment(ExpensesStore.self) private var expenses
    @Environment(\.theme) private var theme
    @State private var rate: RateQuote?

    private var progress: TripProgress? { trips.progress[trip.id] }
    private var referenceCurrency: String { trip.currency == "PLN" ? "EUR" : trip.currency }
    private var rateSubtitle: String? {
        rate.map { "1 \(MoneyFormat.symbol(currency: referenceCurrency)) = \($0.value.rate.formatted(.number.locale(Locale(identifier: "pl_PL")).precision(.fractionLength(2)))) \(MoneyFormat.symbol(currency: "PLN"))" }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s24) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.s12), GridItem(.flexible(), spacing: Spacing.s12)], spacing: Spacing.s12) {
                    ToolTile(icon: .currencyExchange, title: "Kalkulator walut", subtitle: rateSubtitle, style: .large) {
                        CurrencyCalculatorView(trip: trip, user: user)
                    }
                    ToolTile(icon: .straighten, title: "Jednostki", subtitle: "km, kg, °C, rozmiary", style: .large) { UnitConverterView() }
                    ToolTile(icon: .howToVote, title: "Głosowania", subtitle: pollSubtitle, style: .large, warning: (progress?.polls.awaitingMyVoteCount ?? 0) > 0) {
                        PollsView(trip: trip, user: user)
                    }
                    ToolTile(icon: .checklist, title: "Do zrobienia", subtitle: progress.map { "\($0.tasks.doneCount) z \($0.tasks.totalCount) zrobione" }, style: .large) {
                        TasksView(trip: trip, user: user)
                    }
                    ToolTile(icon: .luggage, title: "Pakowanie", subtitle: progress.map { "\($0.packing.mine.packedCount) z \($0.packing.mine.totalCount) spakowane" }, style: .large) {
                        PackingView(trip: trip, user: user)
                    }
                    ToolTile(icon: .stickyNote2, title: "Notatki", subtitle: notesSubtitle, style: .large) { NotesView(trip: trip, user: user) }
                    ToolTile(icon: .folder, title: "Dokumenty", subtitle: documentsSubtitle, style: .large) { DocumentsView(trip: trip, user: user) }
                    ToolTile(icon: .accountBalance, title: "Rozliczenia", subtitle: settlementSubtitle, style: .large) { SettlementView(trip: trip, user: user) }
                }
                Text("Narzędzia działają też offline. Kursy walut odświeżają się po połączeniu z internetem.")
                    .typography(.footnote).foregroundStyle(.neutralGray)
                    .padding(.horizontal, Spacing.s6)
            }
            .padding(Spacing.gutter)
        }
        .background { theme.background.ignoresSafeArea() }
        .navigationTitle("Narzędzia")
        .navigationSubtitle(trip.name)
        .toolbar(.hidden, for: .tabBar)
        .refreshRatesOnReconnect {
            rate = try? await expenses.rates.quote(from: referenceCurrency, to: "PLN", on: LocalDate(.now, calendar: user.calendar), in: trip, allowStale: true)
        }
        .task(id: [trip.id, trip.currency]) {
            try? await trips.loadProgress(of: trip)
            try? await documents.load(trip)
            try? await expenses.loadSettlement(trip)
            rate = try? await expenses.rates.quote(from: referenceCurrency, to: "PLN", on: LocalDate(.now, calendar: user.calendar), in: trip, allowStale: true)
        }
    }

    private var pollSubtitle: String? {
        guard let progress else { return nil }
        return progress.polls.awaitingMyVoteCount > 0 ? "Brakuje Twojego głosu" : "\(progress.polls.openCount) otwarte"
    }
    private var notesSubtitle: String? {
        documents.notes(for: trip).map { "\($0.filter(\.pinned).count) przypięte" }
    }
    private var documentsSubtitle: String? {
        documents.documents(for: trip).map { PolishPlural.form($0.count, one: "1 plik", few: "\($0.count) pliki", many: "\($0.count) plików") }
    }
    private var settlementSubtitle: String? {
        expenses.settlement(for: trip).map {
            let balance = $0.balance(of: user.id)
            return balance < 0 ? "Do zapłaty \(MoneyFormat.precise(minorUnits: -balance, currency: trip.currency))" : balance > 0 ? "Do odebrania \(MoneyFormat.precise(minorUnits: balance, currency: trip.currency))" : "Rozliczone"
        }
    }
}
