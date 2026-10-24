import SwiftUI

private struct EmailField: View {
    let email: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("E-mail")
                .typography(.captionRegular)
                .foregroundStyle(.neutralGray)
            Text(email)
                .typography(.bodyLarge)
                .foregroundStyle(.neutralInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.s16)
        .padding(.vertical, Spacing.s12)
    }
}

struct PersonalDetailsView: View {
    let user: AuthUser
    @State private var firstName: String
    @State private var lastName: String
    @State private var nickname: String
    @State private var phone: String

    init(user: AuthUser) {
        self.user = user
        _firstName = State(initialValue: user.firstName ?? "")
        _lastName = State(initialValue: user.lastName ?? "")
        _nickname = State(initialValue: user.name)
        _phone = State(initialValue: user.phone.map(FieldFormat.phone) ?? "")
    }

    private var request: UpdateUserRequest {
        let name = nickname.trimmingCharacters(in: .whitespaces)
        return UpdateUserRequest(
            name: name == user.name ? nil : name,
            firstName: FieldFormat.change(FieldFormat.trimmed(firstName), from: user.firstName),
            lastName: FieldFormat.change(FieldFormat.trimmed(lastName), from: user.lastName),
            phone: FieldFormat.change(FieldFormat.compact(phone), from: user.phone)
        )
    }

    var body: some View {
        ProfileFormScreen(
            title: "Dane osobowe",
            request: request,
            isValid: FieldFormat.trimmed(nickname) != nil
        ) {
            FormSection(title: "DANE", footnote: "Tak zobaczą Cię inni uczestnicy — przy wydatkach i na liście ekipy.") {
                LabeledField(label: "Imię", text: $firstName)
                    .textContentType(.givenName)
                LabeledField(label: "Nazwisko", text: $lastName)
                    .textContentType(.familyName)
                LabeledField(label: "Jak Cię nazywać w ekipie", text: $nickname)
                    .textContentType(.nickname)
            }

            FormSection(title: "KONTAKT") {
                EmailField(email: user.email)
                LabeledField(label: "Telefon", text: $phone, prompt: "+48 000 000 000")
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            }
        }
    }
}

#Preview {
    NavigationStack {
        PersonalDetailsView(user: AuthUser(
            id: "preview",
            name: "Kubson",
            email: "kuba@zmykamy.pl",
            image: nil,
            themePalette: "ocean",
            termsVersion: AuthStore.currentTermsVersion,
            termsAcceptedAt: .now,
            emailVerified: true,
            firstName: "Kuba",
            lastName: "Nowak",
            phone: "+48512345678"
        ))
    }
    .environment(AuthStore())
}
