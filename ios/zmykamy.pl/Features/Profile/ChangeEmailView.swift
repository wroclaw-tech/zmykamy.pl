import SwiftUI

struct ChangeEmailView: View {
    let user: AuthUser
    @State private var email = ""

    private var newEmail: String {
        email.trimmingCharacters(in: .whitespaces).lowercased()
    }

    var body: some View {
        ProfileFormScreen(
            title: "E-mail",
            canSave: newEmail.contains("@") && newEmail != user.email,
            onSave: { (auth: AuthStore) async throws(AuthError) in try await auth.changeEmail(to: newEmail) }
        ) {
            FormSection(title: "NOWY ADRES", footnote: "Obecny adres: \(user.email)") {
                LabeledField(label: "E-mail", text: $email, prompt: user.email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChangeEmailView(user: AuthUser(
            id: "preview",
            name: "Kuba",
            email: "kuba@zmykamy.pl",
            image: nil,
            themePalette: "ocean",
            termsVersion: AuthStore.currentTermsVersion,
            termsAcceptedAt: .now
        ))
    }
    .environment(AuthStore())
}
