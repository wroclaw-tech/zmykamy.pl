import SwiftUI

struct UnitConverterView: View {
    @Environment(\.theme) private var theme
    @State private var category = UnitCategory.length
    @State private var from = ConversionUnit.kilometers
    @State private var to = ConversionUnit.miles
    @State private var input = "5"

    private var result: Double? {
        guard let decimal = MoneyFormat.decimal(from: input) else { return nil }
        return from.convert(NSDecimalNumber(decimal: decimal).doubleValue, to: to)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s16) {
                Picker("Rodzaj jednostek", selection: Binding(get: { category }, set: { select($0) })) {
                    ForEach(UnitCategory.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                ConversionCard {
                    unitRow(from, selection: $from) {
                        TextField("Wartość", text: $input)
                            .keyboardType(category == .temperature ? .numbersAndPunctuation : .decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("Wartość do przeliczenia")
                    }
                } target: {
                    unitRow(to, selection: $to) {
                        Text(result.map { $0.formatted(.number.locale(Locale(identifier: "pl_PL")).precision(.fractionLength(0...2))) } ?? "—")
                            .foregroundStyle(theme.accentStrong)
                    }
                } swap: {
                    if let result {
                        input = result.formatted(.number.locale(Locale(identifier: "pl_PL")).grouping(.never).precision(.fractionLength(0...6)))
                    }
                    (from, to) = (to, from)
                }
                if result == nil {
                    Text("Sprawdź wartość i wybrane jednostki.").typography(.footnote).foregroundStyle(.statusDanger)
                }
                if category == .sizes {
                    Text("Rozmiary butów są orientacyjne. Sprawdź tabelę producenta.")
                        .typography(.footnote).foregroundStyle(.neutralGray)
                }
                SectionLabel(text: "SZYBKIE PRZELICZENIA")
                ListCard(separatorInset: 62) {
                    quick(.thermostat, "Temperatura", "24 °C = 75 °F", category: .temperature, from: .celsius, to: .fahrenheit, value: "24")
                    quick(.luggage, "Bagaż podręczny", "10 kg = 22 lb", category: .weight, from: .kilograms, to: .pounds, value: "10")
                    // Speed is a fixed reference; the four tabs cover the design's editable categories.
                    HStack(spacing: Spacing.s12) {
                        IconBadge(image: .directionsCar, foreground: theme.accent, background: theme.accentTint)
                        Text("Prędkość").typography(.bodyRegular)
                        Spacer()
                        Text("120 km/h = 75 mph").typography(.subheadEmphasis)
                    }.padding(Spacing.s14)
                    quick(.straighten, "Rozmiar butów", "42 EU = 8 UK", category: .sizes, from: .euShoes, to: .ukShoes, value: "42")
                }
                Text("Przelicznik działa bez internetu.").typography(.footnote).foregroundStyle(.neutralGray)
                    .padding(.horizontal, Spacing.s6)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.s16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { theme.background.ignoresSafeArea() }
        .navigationTitle("Jednostki")
        .navigationSubtitle("Narzędzia")
        .toolbar(.hidden, for: .tabBar)
    }

    private func select(_ category: UnitCategory) {
        self.category = category
        from = category.units[0]; to = category.units[1]
        input = category == .temperature ? "24" : category == .sizes ? "42" : "5"
    }

    private func unitRow<Value: View>(_ unit: ConversionUnit, selection: Binding<ConversionUnit>, @ViewBuilder value: () -> Value) -> some View {
        HStack(spacing: Spacing.s12) {
            ConversionBadge(text: unit.symbol)
            Menu {
                Picker("Jednostka", selection: selection) {
                    ForEach(category.units) { Text($0.rawValue).tag($0) }
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(unit.rawValue).typography(.bodyEmphasis).foregroundStyle(.neutralInk)
                    Text(category.subtitle).typography(.footnote).foregroundStyle(.neutralGray)
                }
            }
            Spacer(minLength: Spacing.s8)
            value().typography(.title1).frame(minWidth: 65, alignment: .trailing)
        }
    }

    private func quick(_ icon: ImageResource, _ title: String, _ conversion: String, category: UnitCategory, from: ConversionUnit, to: ConversionUnit, value: String) -> some View {
        Button {
            self.category = category
            self.from = from; self.to = to; input = value
        } label: {
            HStack(spacing: Spacing.s12) {
                IconBadge(image: icon, foreground: theme.accent, background: theme.accentTint)
                Text(title).typography(.bodyRegular)
                Spacer(minLength: Spacing.s4)
                Text(conversion).typography(.subheadEmphasis)
            }.foregroundStyle(.neutralInk).padding(Spacing.s14)
        }.buttonStyle(.plain)
    }
}
