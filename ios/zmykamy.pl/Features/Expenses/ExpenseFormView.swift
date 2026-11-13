import SwiftUI

struct ExpenseFormView: View {
    let trip: Trip
    let user: AuthUser
    var expense: Expense?

    @Environment(ExpensesStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var currency: String
    @State private var loadedRateKey: String?
    @State private var quote: RateQuote?
    @State private var rateError: String?
    @State private var isLoadingRate = false
    @State private var customRateText: String
    @State private var usesCustomRate: Bool
    @State private var isChoosingCurrency = false
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

    init(trip: Trip, user: AuthUser, expense: Expense? = nil, draft: ExpenseDraft? = nil) {
        self.trip = trip
        self.user = user
        self.expense = expense
        let enteredCurrency = expense?.original?.currency ?? draft?.currency ?? trip.currency
        let enteredAmount = expense?.original?.amount ?? expense?.amount ?? draft?.amount
        _currency = State(initialValue: enteredCurrency)
        _amountText = State(initialValue: enteredAmount.map { MoneyFormat.input(minorUnits: $0, currency: enteredCurrency) } ?? "")
        _usesCustomRate = State(initialValue: expense?.original?.rateSource == "custom")
        _customRateText = State(initialValue: expense?.original.map { String($0.exchangeRate).replacingOccurrences(of: ".", with: ",") } ?? "")
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

    private var isEditable: Bool {
        expense == nil || trip.isOrganizer || expense?.author?.userId == user.id
    }

    private var members: [TripMember] {
        trip.members.filter { $0.userId == user.id } + trip.members.filter { $0.userId != user.id }
    }

    private var amount: Int? {
        MoneyFormat.minorUnits(from: amountText, currency: currency)
    }

    private var exchangeRate: Double? {
        if currency == trip.currency { return 1 }
        if usesCustomRate {
            guard let decimal = MoneyFormat.decimal(from: customRateText) else { return nil }
            let rate = NSDecimalNumber(decimal: decimal).doubleValue
            return rate.isFinite && rate > 0 && rate <= 1_000_000 ? rate : nil
        }
        return loadedRateKey == rateKey ? quote?.value.rate : nil
    }

    private var convertedAmount: Int? {
        guard let amount, let exchangeRate else { return nil }
        return MoneyFormat.convert(amount, from: currency, to: trip.currency, rate: exchangeRate)
    }

    private var rateKey: String { "\(currency)-\(LocalDate(date, calendar: calendar).rawValue)" }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var shares: [String: Int] {
        ExpenseSplit.evenly(convertedAmount ?? 0, between: Array(participants))
    }

    private var canSave: Bool {
        isEditable && (amount ?? 0) <= 100_000_000 && (convertedAmount ?? 0) > 0 && (convertedAmount ?? 0) <= Int(Int32.max) && !trimmedTitle.isEmpty && !participants.isEmpty && !isSaving && (usesCustomRate || !isLoadingRate)
    }

    private var currencySymbol: String {
        MoneyFormat.symbol(currency: currency)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.s12) {
                    Group {
                        amountHeader
                        titleField
                        currencyCard
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
                    }
                    .disabled(!isEditable)
                    if !isEditable {
                        Text("Ten wydatek może zmienić tylko osoba, która go dodała, albo organizator.")
                            .typography(.footnote)
                            .foregroundStyle(.neutralGray)
                            .multilineTextAlignment(.center)
                            .padding(.top, Spacing.s8)
                    } else {
                        PrimaryButton(title: expense == nil ? "Dodaj wydatek" : "Zapisz zmiany", isEnabled: canSave, action: save)
                            .padding(.top, Spacing.s12)
                    }
                    if expense != nil && isEditable {
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
            .navigationTitle(expense == nil ? "Nowy wydatek" : isEditable ? "Edytuj wydatek" : "Wydatek")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                if isEditable {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(role: .confirm, action: save)
                            .disabled(!canSave)
                    }
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
        .sheet(isPresented: $isChoosingCurrency) {
            NavigationStack { CurrencyPickerView(selection: $currency) }
        }
        .task(id: rateKey) { await loadRate() }
        .refreshRatesOnReconnect { await loadRate() }
        .onChange(of: currency) { _, _ in usesCustomRate = false }
        .task {
            guard expense == nil, amountText.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(500))
            isAmountFocused = true
        }
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
                .typography(.subheadRegular)
                .foregroundStyle(.neutralGray)
        }
        .padding(.vertical, Spacing.s16)
    }

    private var perPersonText: String {
        guard !participants.isEmpty else { return "Wybierz, na kogo dzielimy" }
        guard let convertedAmount else { return "Wybierz kurs przeliczenia" }
        let perPerson = Int((Double(convertedAmount) / Double(participants.count)).rounded())
        let prefix = currency == trip.currency ? "" : "≈ \(MoneyFormat.precise(minorUnits: convertedAmount, currency: trip.currency)) · "
        return prefix + "\(MoneyFormat.string(minorUnits: perPerson, currency: trip.currency)) na osobę · \(participants.count) os."
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

    private var currencyCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s12) {
            ListCard(separatorInset: Spacing.s14) {
                HStack(spacing: Spacing.s12) {
                    IconBadge(image: .currencyExchange, foreground: theme.accent, background: theme.accentTint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Waluta wydatku").typography(.bodyRegular)
                        Text("Waluta wyjazdu: \(trip.currency)").typography(.footnote).foregroundStyle(.neutralGray)
                    }
                    Spacer(minLength: 0)
                    Button { isChoosingCurrency = true } label: {
                        HStack(spacing: Spacing.s4) {
                            Text("\(currency) · \(currencySymbol)")
                            Image(systemName: "chevron.down").font(.caption2)
                        }
                        .typography(.subheadEmphasis)
                        .padding(.horizontal, Spacing.s12).padding(.vertical, Spacing.s8)
                        .background(theme.accentTint, in: .capsule)
                    }
                    .accessibilityLabel("Waluta wydatku: \(currency)")
                }
                .padding(Spacing.s14)
                if currency != trip.currency {
                    HStack(spacing: Spacing.s12) {
                        IconBadge(image: .accountBalance, foreground: theme.accent, background: theme.accentTint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(usesCustomRate ? "Własny kurs" : "Kurs średni NBP").typography(.bodyRegular)
                            if let quote, !usesCustomRate {
                                Text([quote.value.table.map { "Tabela \($0)" }, quote.value.dateLabel].compactMap { $0 }.joined(separator: " · "))
                                    .typography(.footnote).foregroundStyle(.neutralGray)
                            }
                        }
                        Spacer(minLength: 0)
                        if isLoadingRate && !usesCustomRate {
                            ProgressView()
                        } else if let exchangeRate {
                            VStack(alignment: .trailing, spacing: 0) {
                                Text("\(exchangeRate.formatted(.number.locale(Locale(identifier: "pl_PL")).precision(.fractionLength(4)))) \(MoneyFormat.symbol(currency: trip.currency))")
                                    .typography(.bodyEmphasis)
                                Text("za 1 \(currencySymbol)").typography(.captionRegular).foregroundStyle(.neutralGray)
                            }
                        }
                    }
                    .padding(Spacing.s14)
                }
            }
            if currency != trip.currency {
                DisclosureGroup("Własny kurs", isExpanded: $usesCustomRate) {
                    TextField("Kurs za 1 \(currency)", text: $customRateText)
                        .keyboardType(.decimalPad).typography(.bodyRegular)
                        .padding(Spacing.s12)
                        .background(.neutralWhite, in: .rect(cornerRadius: Radius.sm))
                }
                .typography(.subheadRegular)
                if !usesCustomRate, let rateError {
                    Text(rateError).typography(.footnote).foregroundStyle(.statusDanger)
                    Button("Spróbuj ponownie") { Task { await loadRate() } }.typography(.subheadEmphasis)
                }
                if quote?.isOffline == true && !usesCustomRate {
                    Text("Kurs zapisany offline. Przy zapisie sprawdzimy kurs NBP ponownie.")
                        .typography(.footnote).foregroundStyle(.neutralGray)
                }
            }
        }
    }

    private func loadRate() async {
        guard !Task.isCancelled else { return }
        let requestedKey = rateKey
        let requestedCurrency = currency
        quote = nil
        rateError = nil
        guard currency != trip.currency else { isLoadingRate = false; return }
        isLoadingRate = true
        do {
            let fetched = try await store.rates.quote(from: requestedCurrency, to: trip.currency, on: LocalDate(date, calendar: calendar), in: trip)
            guard !Task.isCancelled, requestedKey == rateKey else { return }
            quote = fetched
            loadedRateKey = requestedKey
        } catch {
            guard !Task.isCancelled, requestedKey == rateKey else { return }
            rateError = error.localizedDescription
        }
        if requestedKey == rateKey { isLoadingRate = false }
    }

    private var payerPicker: some View {
        VStack(spacing: Spacing.s8) {
            SectionLabel(text: "PŁATNIK")
                .padding(.top, Spacing.s8)
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.s8) {
                    ForEach(members) { member in
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
                ForEach(members) { member in
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
        guard canSave, let amount else { return }
        let request = ExpenseRequest(
            title: trimmedTitle,
            amount: amount,
            date: LocalDate(date, calendar: calendar),
            icon: icon,
            paidBy: paidBy,
            participants: participants.sorted(),
            currency: currency,
            exchangeRate: usesCustomRate ? .some(exchangeRate) : expense == nil ? nil : .some(nil)
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
