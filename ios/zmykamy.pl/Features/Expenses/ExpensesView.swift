import SwiftUI

private struct ExpenseSheet: Identifiable {
    let id = UUID()
    var expense: Expense?
}

struct ExpensesView: View {
    let trip: Trip
    let user: AuthUser

    @Environment(ExpensesStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var sheet: ExpenseSheet?
    @State private var isShowingSettlement = false
    @State private var loadError: String?
    @State private var isShowingRefreshError = false

    private var calendar: Calendar {
        user.calendar
    }

    var body: some View {
        NavigationStack {
            content
                .background { theme.background.ignoresSafeArea() }
                .navigationTitle("Wydatki")
                .navigationSubtitle(trip.name)
                .toolbar {
                    CloseTripButton()
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Dodaj wydatek", image: .addRounded) { sheet = ExpenseSheet() }
                    }
                }
                .navigationDestination(isPresented: $isShowingSettlement) {
                    SettlementView(trip: trip, user: user)
                }
                .sheet(item: $sheet) { sheet in
                    ExpenseFormView(trip: trip, user: user, expense: sheet.expense)
                }
                .alert("Nie udało się odświeżyć", isPresented: $isShowingRefreshError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(loadError ?? "")
                }
        }
        .task(id: trip.id) { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if let expenses = store.expenses(for: trip) {
            let summary = ExpenseSummary(expenses: expenses, members: trip.members, userID: user.id)
            ScrollView {
                VStack(spacing: Spacing.s8) {
                    ExpenseSummaryCard(
                        summary: summary,
                        balance: store.settlement(for: trip)?.balance(of: user.id),
                        currency: trip.currency,
                        userID: user.id,
                        onSettle: { isShowingSettlement = true }
                    )
                    .padding(.bottom, Spacing.s16)

                    if expenses.isEmpty {
                        ContentUnavailableView {
                            Label("Brak wydatków", image: .payments)
                        } description: {
                            Text("Dodaj pierwszy wydatek, a policzymy, kto komu ile oddaje.")
                        }
                        DashedAddButton(title: "Dodaj wydatek") { sheet = ExpenseSheet() }
                    }

                    ForEach(summary.days) { day in
                        daySection(day)
                    }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.bottom, Spacing.s24)
            }
            .refreshable { await refresh() }
        } else if let loadError {
            ContentUnavailableView {
                Label("Nie udało się wczytać wydatków", image: .payments)
            } description: {
                Text(loadError)
            } actions: {
                Button("Spróbuj ponownie") { Task { await load() } }
                    .buttonStyle(.glassProminent)
            }
        } else {
            ProgressView()
        }
    }

    private func daySection(_ day: ExpenseDay) -> some View {
        VStack(spacing: Spacing.s8) {
            HStack {
                Text(dayTitle(day.date))
                Spacer()
                Text(MoneyFormat.string(minorUnits: day.total, currency: trip.currency))
                    .typography(.footnote)
            }
            .typography(.sectionLabel)
            .foregroundStyle(.neutralGray)
            .padding(.horizontal, Spacing.s6)

            ListCard(separatorInset: Spacing.s14) {
                ForEach(day.expenses) { expense in
                    let isEditable = trip.isOrganizer || expense.author?.userId == user.id
                    Button { sheet = ExpenseSheet(expense: expense) } label: {
                        ExpenseRow(expense: expense, members: trip.members, currency: trip.currency, userID: user.id)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isEditable)
                }
            }
        }
        .padding(.bottom, Spacing.s12)
    }

    private func dayTitle(_ date: LocalDate) -> String {
        let today = LocalDate(.now, calendar: calendar)
        if date == today { return "DZIŚ" }
        if date == today.adding(days: -1, calendar: calendar) { return "WCZORAJ" }
        return "\(PlanDateFormat.shortWeekday(date, calendar: calendar)), \(TripDateFormat.dayMonth(date, calendar: calendar))"
            .uppercased(with: Locale(identifier: "pl_PL"))
    }

    private func load() async {
        loadError = nil
        do throws(APIError) {
            try await store.load(trip)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func refresh() async {
        do throws(APIError) {
            try await store.load(trip)
        } catch {
            loadError = error.localizedDescription
            isShowingRefreshError = true
        }
    }
}
