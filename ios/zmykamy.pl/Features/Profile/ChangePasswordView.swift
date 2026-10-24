import SwiftUI

struct ChangePasswordView: View {
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var signOutOtherDevices = true

    var body: some View {
        ProfileFormScreen(
            title: "Hasło",
            canSave: !currentPassword.isEmpty && newPassword.count >= AuthClient.minPasswordLength,
            onSave: { (auth: AuthStore) async throws(AuthError) in
                try await auth.changePassword(current: currentPassword, new: newPassword, signOutOtherDevices: signOutOtherDevices)
            }
        ) {
            FormSection(title: "ZMIANA HASŁA", footnote: "Nowe hasło musi mieć co najmniej \(AuthClient.minPasswordLength) znaków.") {
                LabeledField(label: "Obecne hasło", text: $currentPassword, isSecure: true)
                    .textContentType(.password)
                LabeledField(label: "Nowe hasło", text: $newPassword, isSecure: true)
                    .textContentType(.newPassword)
                Toggle("Wyloguj z innych urządzeń", isOn: $signOutOtherDevices)
                    .typography(.bodyRegular)
                    .foregroundStyle(.neutralInk)
                    .padding(.horizontal, Spacing.s16)
                    .padding(.vertical, Spacing.s12)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChangePasswordView()
    }
    .environment(AuthStore())
}
