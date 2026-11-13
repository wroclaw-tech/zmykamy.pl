import SwiftUI

struct CurrencyCalculatorView: View {
    let trip: Trip
    let user: AuthUser
    @Environment(ExpensesStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var from: String
    @State private var to: String
    @State private var input = "25"
    @State private var loadedKey: String?
    @State private var quote: RateQuote?
    @State private var error: String?
    @State private var isLoading = false
    @State private var draft: ExpenseDraft?
    @State private var picker: CurrencySide?

    private enum CurrencySide: String, Identifiable {
        case source, target
        var id: Self { self }
    }

    init(trip: Trip, user: AuthUser) {
        self.trip = trip; self.user = user
        _from = State(initialValue: trip.currency == "PLN" ? "EUR" : trip.currency)
        _to = State(initialValue: "PLN")
    }

    private var day: LocalDate { LocalDate(.now, calendar: user.calendar) }
    private var key: String { "\(from)-\(to)-\(day.rawValue)" }
    private var amount: Int? { MoneyFormat.minorUnits(from: input, currency: from) }
    private var converted: Int? {
        guard loadedKey == key, let amount, let quote else { return nil }
        return MoneyFormat.convert(amount, from: from, to: to, rate: quote.value.rate)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s24) {
                ConversionCard {
                    currencyRow(from, side: .source, value: input)
                } target: {
                    currencyRow(to, side: .target, value: converted.map { MoneyFormat.input(minorUnits: $0, currency: to) } ?? "—")
                } swap: {
                    if let converted { input = MoneyFormat.input(minorUnits: converted, currency: to) }
                    (from, to) = (to, from)
                }
                rateStatus
                VStack(spacing: Spacing.s16) {
                    HStack(spacing: Spacing.s8) {
                        ForEach([5, 10, 20, 50, 100], id: \.self) { value in
                            Button { input = "\(value)" } label: {
                                Text("\(value) \(MoneyFormat.symbol(currency: from))")
                                    .typography(.subheadEmphasis)
                                    .lineLimit(1).minimumScaleFactor(0.6)
                                    .frame(maxWidth: .infinity).frame(height: 34)
                                    .background(.neutralWhite, in: .capsule)
                            }.buttonStyle(.plain)
                        }
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.s8), count: 3), spacing: Spacing.s8) {
                        ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", ",", "0", "⌫"], id: \.self) { key in
                            Button { press(key) } label: {
                                Group {
                                    if key == "⌫" {
                                        Image(.backspace).resizable().scaledToFit().frame(width: 24, height: 24)
                                    } else { Text(key).typography(.title3) }
                                }
                                .frame(maxWidth: .infinity).frame(height: 50)
                                .background(key == "⌫" ? Color.alphaFill : .neutralWhite, in: .rect(cornerRadius: Radius.md))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(key == "⌫" ? "Usuń ostatnią cyfrę" : key)
                        }
                    }
                }
                Spacer(minLength: 40)
            }
            .foregroundStyle(.neutralInk)
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.s16)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Dodaj jako wydatek", icon: .addRounded, isEnabled: (amount ?? 0) > 0 && (amount ?? 0) <= 100_000_000, iconFirst: true) {
                if let amount { draft = ExpenseDraft(amount: amount, currency: from) }
            }
            .padding(Spacing.gutter)
            .background(theme.background)
        }
        .background { theme.background.ignoresSafeArea() }
        .navigationTitle("Kalkulator walut")
        .navigationSubtitle("Narzędzia")
        .toolbar(.hidden, for: .tabBar)
        .task(id: key) { await load() }
        .refreshable { await load() }
        .refreshRatesOnReconnect { await load() }
        .sheet(item: $picker) { side in
            NavigationStack { CurrencyPickerView(selection: side == .source ? $from : $to) }
        }
        .sheet(item: $draft) { ExpenseFormView(trip: trip, user: user, draft: $0) }
    }

    private func currencyRow(_ code: String, side: CurrencySide, value: String) -> some View {
        HStack(spacing: Spacing.s12) {
            ConversionBadge(text: MoneyFormat.symbol(currency: code))
            Button { picker = side } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(code).typography(.bodyEmphasis).foregroundStyle(.neutralInk)
                    Text(Currency.name(code)).typography(.footnote).foregroundStyle(.neutralGray)
                }
            }.accessibilityLabel("\(side == .source ? "Waluta źródłowa" : "Waluta docelowa"): \(code)")
            Spacer(minLength: Spacing.s8)
            Text(value).typography(.title1)
                .foregroundStyle(side == .source ? .neutralInk : theme.accentStrong)
                .lineLimit(1).minimumScaleFactor(0.5)
                .accessibilityLabel("\(value) \(code)")
        }
    }

    @ViewBuilder private var rateStatus: some View {
        if isLoading {
            ProgressView("Pobieranie kursu…").typography(.footnote)
        } else if let quote {
            VStack(alignment: .leading, spacing: Spacing.s6) {
                Label {
                    Text("\(quote.value.attribution) · 1 \(MoneyFormat.symbol(currency: from)) = \(quote.value.rate.formatted(.number.locale(Locale(identifier: "pl_PL")).precision(.fractionLength(4)))) \(MoneyFormat.symbol(currency: to))")
                } icon: { Image(.info).resizable().frame(width: 14, height: 14) }
                if quote.isOffline { Text("Offline · zapisany kurs. Odświeży się po połączeniu.") }
            }.typography(.footnote).foregroundStyle(.neutralGray)
        } else if let error {
            VStack(alignment: .leading, spacing: Spacing.s8) {
                Text(error).foregroundStyle(.statusDanger)
                Button("Spróbuj ponownie") { Task { await load() } }
            }.typography(.footnote)
        }
    }

    private func press(_ key: String) {
        if key == "⌫" { input = String(input.dropLast()); return }
        if key == "," {
            if !input.contains(","), MoneyFormat.digits(for: from) > 0 { input = (input.isEmpty ? "0" : input) + "," }
            return
        }
        let candidate = input == "0" ? key : input + key
        guard candidate.count <= 12 else { return }
        if let fraction = candidate.split(separator: ",", omittingEmptySubsequences: false).dropFirst().first,
           fraction.count > MoneyFormat.digits(for: from) { return }
        input = candidate
    }

    private func load() async {
        guard !Task.isCancelled else { return }
        let requestedKey = key
        let source = from; let target = to; let requestedDay = day
        quote = nil; error = nil; isLoading = true
        do {
            let fetched = try await store.rates.quote(from: source, to: target, on: requestedDay, in: trip, allowStale: true)
            guard !Task.isCancelled, key == requestedKey else { return }
            quote = fetched
            loadedKey = requestedKey
        } catch {
            guard !Task.isCancelled, key == requestedKey else { return }
            self.error = error.localizedDescription
        }
        if key == requestedKey { isLoading = false }
    }
}
