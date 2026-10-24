import SwiftUI

struct FormSection<Content: View>: View {
    let title: String
    var footnote: String?
    var separatorInset = Spacing.s16
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: Spacing.s8) {
            SectionLabel(text: title)
            ListCard(separatorInset: separatorInset) {
                content
            }
            if let footnote {
                Text(footnote)
                    .typography(.footnote)
                    .foregroundStyle(.neutralGray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.s6)
            }
        }
    }
}

struct ProfileFormScreen<Content: View>: View {
    let title: String
    let canSave: Bool
    let onSave: (AuthStore) async throws(AuthError) -> Void
    @ViewBuilder let content: Content
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var isShowingError = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.s24) {
                content
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.s12)
            .padding(.bottom, 48)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { theme.background.ignoresSafeArea() }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm, action: save)
                    .disabled(!canSave || isSaving)
            }
        }
        .alert("Nie udało się zapisać", isPresented: $isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func save() {
        isSaving = true
        Task {
            do throws(AuthError) {
                try await onSave(auth)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isShowingError = true
            }
            isSaving = false
        }
    }
}

extension ProfileFormScreen {
    init(title: String, request: UpdateUserRequest, isValid: Bool = true, @ViewBuilder content: () -> Content) {
        self.init(title: title, canSave: !request.isEmpty && isValid, onSave: { (auth: AuthStore) async throws(AuthError) in try await auth.updateUser(request) }, content: content)
    }
}

enum FieldFormat {
    static func change(_ value: String?, from current: String?) -> String?? {
        value == current ? nil : .some(value)
    }

    static func trimmed(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func compact(_ value: String) -> String? {
        let compact = value.filter { !$0.isWhitespace }
        return compact.isEmpty ? nil : compact
    }

    static func phone(_ phone: String) -> String {
        guard phone.hasPrefix("+48"), phone.count == 12 else { return phone }
        let digits = Array(phone.dropFirst(3))
        return "+48 \(String(digits[0..<3])) \(String(digits[3..<6])) \(String(digits[6..<9]))"
    }

    static func iban(_ iban: String) -> String {
        stride(from: 0, to: iban.count, by: 4)
            .map { offset in
                let start = iban.index(iban.startIndex, offsetBy: offset)
                let end = iban.index(start, offsetBy: 4, limitedBy: iban.endIndex) ?? iban.endIndex
                return String(iban[start..<end])
            }
            .joined(separator: " ")
    }
}
