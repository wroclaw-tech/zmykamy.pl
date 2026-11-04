import SwiftUI

struct TaskFormView: View {
    let trip: Trip
    let user: AuthUser
    var task: TripTask?

    @Environment(TasksStore.self) private var tasks
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var title: String
    @State private var assigneeID: String?
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var isSaving = false
    @State private var isConfirmingDelete = false
    @State private var errorMessage = ""
    @State private var isShowingError = false

    init(trip: Trip, user: AuthUser, task: TripTask? = nil) {
        self.trip = trip
        self.user = user
        self.task = task
        let calendar = user.calendar
        _title = State(initialValue: task?.title ?? "")
        _assigneeID = State(initialValue: task == nil ? user.id : task?.assigneeId)
        _hasDueDate = State(initialValue: task?.dueDate != nil)
        _dueDate = State(initialValue: (task?.dueDate ?? trip.startDate.adding(days: -1, calendar: calendar)).date(in: calendar))
    }

    private var calendar: Calendar {
        user.calendar
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedTitle.isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.s12) {
                    FormCard(title: "Co?") {
                        FormFieldRow {
                            TextField("Zadanie", text: $title, prompt: Text("np. Kupić bilety na pociąg"))
                                .typography(.bodyRegular)
                                .foregroundStyle(.neutralInk)
                                .textInputAutocapitalization(.sentences)
                        }
                    }
                    FormCard(title: "Kto?") {
                        FormFieldRow {
                            Picker("Osoba", selection: $assigneeID) {
                                Text("Nikt").tag(String?.none)
                                ForEach(trip.members) { member in
                                    Text(member.userId == user.id ? "Ty" : member.name).tag(Optional(member.userId))
                                }
                            }
                            .typography(.bodyRegular)
                        }
                    }
                    FormCard(title: "Termin") {
                        FormFieldRow {
                            Toggle("Ustaw termin", isOn: $hasDueDate.animation())
                                .typography(.bodyRegular)
                        }
                        if hasDueDate {
                            FormFieldRow {
                                DatePicker("Do kiedy", selection: $dueDate, displayedComponents: .date)
                                    .typography(.bodyRegular)
                            }
                        }
                    }
                    PrimaryButton(title: task == nil ? "Dodaj zadanie" : "Zapisz zmiany", isEnabled: canSave, action: save)
                        .padding(.top, Spacing.s12)
                    if task != nil {
                        Button("Usuń zadanie", role: .destructive) { isConfirmingDelete = true }
                            .typography(.bodyEmphasis)
                            .foregroundStyle(.statusDanger)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .disabled(isSaving)
                    }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.top, Spacing.s20)
                .padding(.bottom, Spacing.s24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { theme.background.ignoresSafeArea() }
            .navigationTitle(task == nil ? "Nowe zadanie" : "Edytuj zadanie")
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
            .confirmationDialog("Usunąć zadanie?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Usuń zadanie", role: .destructive, action: delete)
            } message: {
                Text("Zadanie zniknie z listy dla wszystkich uczestników.")
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
    }

    private func save() {
        let date = hasDueDate ? LocalDate(dueDate, calendar: calendar) : nil
        run { () async throws(APIError) in
            if let task {
                let update = TripTaskUpdate(title: trimmedTitle, assigneeId: .some(assigneeID), dueDate: .some(date))
                try await tasks.update(task, with: update, in: trip)
            } else {
                let request = TripTaskRequest(title: trimmedTitle, assigneeId: assigneeID, dueDate: date)
                try await tasks.add(request, to: trip)
            }
        }
    }

    private func delete() {
        guard let task else { return }
        run { () async throws(APIError) in try await tasks.delete(task, from: trip) }
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
