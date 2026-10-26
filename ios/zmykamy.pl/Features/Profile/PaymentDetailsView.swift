import SwiftUI

struct PaymentDetailsView: View {
    let user: AuthUser
    @State private var blikPhone: String
    @State private var iban: String

    init(user: AuthUser) {
        self.user = user
        _blikPhone = State(initialValue: user.blikPhone.map(FieldFormat.phone) ?? "")
        _iban = State(initialValue: user.iban.map(FieldFormat.iban) ?? "")
    }

    private var request: UpdateUserRequest {
        UpdateUserRequest(
            blikPhone: FieldFormat.change(FieldFormat.compact(blikPhone), from: user.blikPhone),
            iban: FieldFormat.change(FieldFormat.compact(iban)?.uppercased(), from: user.iban)
        )
    }

    var body: some View {
        ProfileFormScreen(title: "Dane do przelewów", request: request) {
            FormSection(
                title: "DO ROZLICZEŃ",
                footnote: "Widoczne tylko dla uczestników Twoich wyjazdów. Pokażemy je przy rozliczeniu, żeby inni mogli szybciej oddać Ci pieniądze."
            ) {
                LabeledField(label: "Telefon do BLIK", text: $blikPhone, prompt: "+48 000 000 000")
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                LabeledField(label: "Numer konta", text: $iban, prompt: "PL00 0000 0000 0000 0000 0000 0000", isMonospaced: true)
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
            }
        }
    }
}

#Preview {
    NavigationStack {
        PaymentDetailsView(user: AuthUser(
            id: "preview",
            name: "Kubson",
            email: "kuba@zmykamy.pl",
            image: nil,
            themePalette: "ocean",
            termsVersion: AuthStore.currentTermsVersion,
            termsAcceptedAt: .now,
            blikPhone: "+48512345678",
            iban: "PL61109010140000071219812874"
        ))
    }
    .environment(AuthStore())
}
