import SwiftUI

enum Currency {
    static let popular = ["PLN", "EUR", "USD", "GBP", "CZK", "CHF"]
    static let all = Locale.commonISOCurrencyCodes

    private static let locale = Locale(identifier: "pl_PL")

    static func name(_ code: String) -> String {
        locale.localizedString(forCurrencyCode: code) ?? code
    }
}

struct CurrencyPickerView: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var query = ""

    private var matches: [String] {
        guard !query.isEmpty else { return Currency.all }
        return Currency.all.filter { code in
            code.localizedCaseInsensitiveContains(query) || Currency.name(code).localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        List {
            if query.isEmpty {
                Section("Popularne") {
                    ForEach(Currency.popular, id: \.self, content: row)
                }
            }
            Section(query.isEmpty ? "Wszystkie" : "Wyniki") {
                ForEach(matches, id: \.self, content: row)
            }
        }
        .searchable(text: $query, prompt: "Szukaj waluty")
        .navigationTitle("Waluta")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ code: String) -> some View {
        Button {
            selection = code
            dismiss()
        } label: {
            HStack {
                Text(code)
                    .typography(.bodyEmphasis)
                    .foregroundStyle(.neutralInk)
                    .frame(width: 52, alignment: .leading)
                Text(Currency.name(code))
                    .typography(.bodyRegular)
                    .foregroundStyle(.neutralInk2)
                Spacer()
                if code == selection {
                    Image(.check)
                        .foregroundStyle(theme.accent)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CurrencyPickerView(selection: .constant("EUR"))
    }
}
