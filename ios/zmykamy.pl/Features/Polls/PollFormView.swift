import SwiftUI

private struct OptionDraft: Identifiable {
    let id = UUID()
    var name = ""
    var description = ""
}

struct PollFormView: View {
    let trip: Trip
    let user: AuthUser

    @Environment(PollsStore.self) private var polls
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var question = ""
    @State private var options = [OptionDraft(), OptionDraft()]
    @State private var hasDeadline = false
    @State private var closesAt = Date.now.addingTimeInterval(24 * 3600)
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var isShowingError = false

    private static let maxOptions = 10

    private var trimmedQuestion: String {
        question.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filledOptions: [PollOptionRequest] {
        options.compactMap { draft in
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : PollOptionRequest(name: name, description: description.isEmpty ? nil : description)
        }
    }

    private var canSave: Bool {
        !trimmedQuestion.isEmpty && filledOptions.count >= 2 && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.s12) {
                    FormCard(title: "Pytanie") {
                        FormFieldRow {
                            TextField("Pytanie", text: $question, prompt: Text("np. Kolacja w piątek: gdzie idziemy?"))
                                .typography(.bodyRegular)
                                .foregroundStyle(.neutralInk)
                                .textInputAutocapitalization(.sentences)
                        }
                    }
                    ForEach($options) { $option in
                        let index = (options.firstIndex { $0.id == option.id } ?? 0) + 1
                        FormCard(title: "Opcja \(index)") {
                            if options.count > 2 {
                                Button("Usuń") { options.removeAll { $0.id == option.id } }
                                    .typography(.subheadEmphasis)
                                    .foregroundStyle(.statusDanger)
                            }
                        } content: {
                            FormFieldRow {
                                TextField("Nazwa", text: $option.name, prompt: Text("np. Time Out Market"))
                                    .typography(.bodyRegular)
                                    .foregroundStyle(.neutralInk)
                                    .textInputAutocapitalization(.sentences)
                            }
                            FormFieldRow {
                                TextField("Opis", text: $option.description, prompt: Text("Opis (opcjonalnie)"))
                                    .typography(.bodyRegular)
                                    .foregroundStyle(.neutralInk)
                                    .textInputAutocapitalization(.sentences)
                            }
                        }
                    }
                    if options.count < Self.maxOptions {
                        DashedAddButton(title: "Dodaj opcję") { options.append(OptionDraft()) }
                    }
                    FormCard(title: "Termin") {
                        FormFieldRow {
                            Toggle("Zakończ głosowanie", isOn: $hasDeadline.animation())
                                .typography(.bodyRegular)
                        }
                        if hasDeadline {
                            FormFieldRow {
                                DatePicker("Do", selection: $closesAt, in: Date.now...)
                                    .typography(.bodyRegular)
                            }
                        }
                    }
                    PrimaryButton(title: "Utwórz głosowanie", isEnabled: canSave, action: save)
                        .padding(.top, Spacing.s12)
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.top, Spacing.s20)
                .padding(.bottom, Spacing.s24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { theme.background.ignoresSafeArea() }
            .navigationTitle("Nowe głosowanie")
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
            .alert("Nie udało się zapisać", isPresented: $isShowingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .environment(\.calendar, user.calendar)
        .environment(\.locale, user.calendar.locale ?? .current)
        .tint(theme.accent)
        .interactiveDismissDisabled(isSaving)
    }

    private func save() {
        let request = PollRequest(question: trimmedQuestion, options: filledOptions, closesAt: hasDeadline ? closesAt : nil)
        isSaving = true
        Task {
            defer { isSaving = false }
            do throws(APIError) {
                try await polls.create(request, in: trip)
            } catch {
                errorMessage = error.localizedDescription
                isShowingError = true
                return
            }
            dismiss()
        }
    }
}
