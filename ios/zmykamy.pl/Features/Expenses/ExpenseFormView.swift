import SwiftUI

struct ExpenseFormView: View {
    let trip: Trip
    let user: AuthUser
    var expense: Expense?

    @Environment(ExpensesStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var amountText: String
    @State private var title: String
    @State private var paidBy: String
    @State private var participants: Set<String>
    @State private var icon: PlanIcon
    @State private var date: Date
    @State private var isSaving = false
    @State private var isConfirmingDelete = false
    @State private var errorMessage = ""
    @State private var isShowingError = false
    @FocusState private var isAmountFocused: Bool

    init(trip: Trip, user: AuthUser, expense: Expense? = nil) {
        self.trip = trip
        self.user = user
        self.expense = expense
        _amountText = State(initialValue: expense.map { MoneyFormat.input(minorUnits: $0.amount) } ?? "")
        _title = State(initialValue: expense?.title ?? "")
        _paidBy = State(initialValue: expense?.paidBy.userId ?? user.id)
        _participants = State(initialValue: Set(expense?.shares.map(\.userId) ?? trip.members.map(\.userId)))
        _icon = State(initialValue: expense?.icon ?? .savings)
        _date = State(initialValue: expense?.date.date(in: user.calendar) ?? Self.defaultDate(for: trip, calendar: user.calendar))
    }

    private static func defaultDate(for trip: Trip, calendar: Calendar) -> Date {
        let today = LocalDate(.now, calendar: calendar)
        let day = today < trip.startDate ? today : min(today, trip.endDate)
        return day.date(in: calendar)
    }

    private var calendar: Calendar {
        user.calendar
    }

    private var amount: Int? {
        MoneyFormat.minorUnits(from: amountText)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var shares: [String: Int] {
        ExpenseSplit.evenly(amount ?? 0, between: Array(participants))
    }

    private var canSave: Bool {
        amount != nil && !trimmedTitle.isEmpty && !participants.isEmpty && !isSaving
    }

    private var currencySymbol: String {
        MoneyFormat.symbol(currency: trip.currency)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.s12) {
                    amountHeader
                    titleField
                    payerPicker
                    splitList
                    FormCard(title: "Kiedy?") {
                        FormFieldRow {
                            DatePicker("Dzień", selection: $date, displayedComponents: .date)
                                .typography(.bodyRegular)
                        }
                    }
                    FormCard(title: "Kategoria") {
                        PlanIconPicker(selection: $icon)
                    }
                    PrimaryButton(title: expense == nil ? "Dodaj wydatek" : "Zapisz zmiany", isEnabled: canSave, action: save)
                        .padding(.top, Spacing.s12)
                    if expense != nil {
                        Button("Usuń wydatek", role: .destructive) { isConfirmingDelete = true }
                            .typography(.bodyEmphasis)
                            .foregroundStyle(.statusDanger)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .disabled(isSaving)
                    }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.bottom, Spacing.s24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { theme.background.ignoresSafeArea() }
            .navigationTitle(expense == nil ? "Nowy wydatek" : "Edytuj wydatek")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm, action: save)
                        .disabled(!canSave)
                }
            }
            .confirmationDialog("Usunąć wydatek?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Usuń wydatek", role: .destructive, action: delete)
            } message: {
                Text("Salda wszystkich uczestników zostaną przeliczone.")
            }
            .alert("Nie udało się zapisać", isPresented: $isShowingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .environment(\.calendar, calendar)
        .environment(\.locale, calendar.locale ?? .current)
        .tint(theme.accent)
        .interactiveDismissDisabled(isSaving)
        .onAppear { isAmountFocused = expense == nil }
    }

    private var amountHeader: some View {
        VStack(spacing: Spacing.s4) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s6) {
                TextField("0", text: $amountText)
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .typography(.displayAmount)
                    .foregroundStyle(.neutralInk)
                    .multilineTextAlignment(.center)
                    .fixedSize()
                    .accessibilityLabel("Kwota")
                Text(currencySymbol)
                    .typography(.title1)
                    .foregroundStyle(.neutralGray2)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
            .onTapGesture { isAmountFocused = true }
            Text(perPersonText)
                .typography(.footnote)
                .foregroundStyle(.neutralGray)
        }
        .padding(.vertical, Spacing.s16)
    }

    private var perPersonText: String {
        guard !participants.isEmpty else { return "Wybierz, na kogo dzielimy" }
        let perPerson = (amount ?? 0) / participants.count
        return "\(MoneyFormat.string(minorUnits: perPerson, currency: trip.currency)) na osobę · \(participants.count) os."
    }

    private var titleField: some View {
        HStack(spacing: Spacing.s12) {
            Image(.edit)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(.neutralGray)
            TextField("Opis", text: $title, prompt: Text("Na co?"))
                .typography(.bodyLarge)
                .foregroundStyle(.neutralInk)
                .textInputAutocapitalization(.sentences)
        }
        .padding(.horizontal, Spacing.s16)
        .frame(height: 52)
        .background(.neutralWhite, in: .rect(cornerRadius: Radius.md))
    }

    private var payerPicker: some View {
        VStack(spacing: Spacing.s8) {
            SectionLabel(text: "PŁATNIK")
                .padding(.top, Spacing.s8)
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.s8) {
                    ForEach(trip.members) { member in
                        payerChip(member)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    private func payerChip(_ member: TripMember) -> some View {
        let isSelected = member.userId == paidBy
        let isViewer = member.userId == user.id
        return Button { paidBy = member.userId } label: {
            HStack(spacing: Spacing.s8) {
                PersonAvatar(userID: member.userId, name: member.name, isViewer: isViewer, size: 30)
                    .overlay { if isSelected { Circle().fill(.neutralWhite.opacity(0.25)) } }
                Text(isViewer ? "Ty" : member.name)
                    .typography(.calloutEmphasis)
                    .foregroundStyle(isSelected ? .neutralWhite : .neutralInk)
            }
            .padding(.leading, Spacing.s4)
            .padding(.trailing, Spacing.s14)
            .frame(height: 40)
            .background(isSelected ? theme.accent : .neutralWhite, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var splitList: some View {
        VStack(spacing: Spacing.s8) {
            HStack {
                Text("PODZIAŁ · PO RÓWNO")
                    .typography(.sectionLabel)
                    .foregroundStyle(.neutralGray)
                Spacer()
                Button(participants.count == trip.members.count ? "Nikt" : "Wszyscy") {
                    participants = participants.count == trip.members.count ? [] : Set(trip.members.map(\.userId))
                }
                .typography(.calloutEmphasis)
                .foregroundStyle(theme.accentStrong)
            }
            .padding(.horizontal, Spacing.s6)
            .padding(.top, Spacing.s8)

            ListCard(separatorInset: Spacing.s14) {
                ForEach(trip.members) { member in
                    splitRow(member)
                }
            }
        }
    }

    private func splitRow(_ member: TripMember) -> some View {
        let isIncluded = participants.contains(member.userId)
        let isViewer = member.userId == user.id
        return Button {
            if isIncluded {
                participants.remove(member.userId)
            } else {
                participants.insert(member.userId)
            }
        } label: {
            HStack(spacing: Spacing.s12) {
                PersonAvatar(userID: member.userId, name: member.name, isViewer: isViewer, size: 32)
                Text(isViewer ? "Ty" : member.name)
                    .typography(.bodyRegular)
                    .foregroundStyle(.neutralInk)
                Spacer()
                Text(isIncluded ? MoneyFormat.string(minorUnits: shares[member.userId] ?? 0, currency: trip.currency) : "—")
                    .typography(.subheadRegular)
                    .foregroundStyle(.neutralGray)
                Group {
                    if isIncluded {
                        Image(.checkCircle)
                            .resizable()
                            .foregroundStyle(theme.accent)
                    } else {
                        Circle()
                            .strokeBorder(.neutralGray3, lineWidth: 1.5)
                    }
                }
                .frame(width: 22, height: 22)
            }
            .padding(.horizontal, Spacing.s14)
            .frame(height: 50)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isIncluded ? .isSelected : [])
    }

    private func save() {
        guard let amount else { return }
        let request = ExpenseRequest(
            title: trimmedTitle,
            amount: amount,
            date: LocalDate(date, calendar: calendar),
            icon: icon,
            paidBy: paidBy,
            participants: participants.sorted()
        )
        run { () async throws(APIError) in
            if let expense {
                try await store.update(expense, with: request, in: trip)
            } else {
                try await store.add(request, to: trip)
            }
        }
    }

    private func delete() {
        guard let expense else { return }
        run { () async throws(APIError) in try await store.delete(expense, from: trip) }
    }

    private func run(_ action: @escaping () async throws(APIError) -> Void) {
        isSaving = true
        Task {
            defer { isSaving = false }
            do throws(APIError) {
                try await action()
            } catch {
                errorMessage = error.localizedDescription
                isShowingError = true
                return
            }
            dismiss()
        }
    }
}
