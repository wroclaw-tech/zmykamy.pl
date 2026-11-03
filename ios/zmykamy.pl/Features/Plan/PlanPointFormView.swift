import SwiftUI

/// Adds a plan point, or edits one when `point` is given.
struct PlanPointFormView: View {
    let trip: Trip
    let user: AuthUser
    var point: PlanPoint?

    @Environment(PlanStore.self) private var plans
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var title: String
    @State private var date: Date
    @State private var time: Date
    @State private var place: String
    @State private var details: String
    @State private var icon: PlanIcon
    @State private var isSaving = false
    @State private var isConfirmingDelete = false
    @State private var errorMessage = ""
    @State private var isShowingError = false

    init(trip: Trip, user: AuthUser, point: PlanPoint? = nil, date: LocalDate) {
        self.trip = trip
        self.user = user
        self.point = point
        let calendar = user.calendar
        _title = State(initialValue: point?.title ?? "")
        _date = State(initialValue: (point?.date ?? date).date(in: calendar))
        _time = State(initialValue: (point?.time ?? PlanTime(hour: 9, minute: 0)).date(calendar: calendar))
        _place = State(initialValue: point?.place ?? "")
        _details = State(initialValue: point?.description ?? "")
        _icon = State(initialValue: point?.icon ?? .locationOn)
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

    private var dateRange: ClosedRange<Date> {
        trip.startDate.date(in: calendar)...trip.endDate.date(in: calendar)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.s12) {
                    FormCard(title: "Co?") {
                        FormFieldRow {
                            TextField("Tytuł", text: $title, prompt: Text("np. Pociąg do Sintry"))
                                .typography(.bodyRegular)
                                .foregroundStyle(.neutralInk)
                                .textInputAutocapitalization(.sentences)
                        }
                    }
                    FormCard(title: "Kiedy?") {
                        FormFieldRow {
                            DatePicker("Dzień", selection: $date, in: dateRange, displayedComponents: .date)
                                .typography(.bodyRegular)
                        }
                        FormFieldRow {
                            DatePicker("Godzina", selection: $time, displayedComponents: .hourAndMinute)
                                .typography(.bodyRegular)
                        }
                    }
                    FormCard(title: "Gdzie?") {
                        FormFieldRow {
                            TextField("Miejsce", text: $place, prompt: Text("np. Dworzec Rossio"))
                                .typography(.bodyRegular)
                                .foregroundStyle(.neutralInk)
                                .textInputAutocapitalization(.sentences)
                        }
                    }
                    FormCard(title: "Opis") {
                        FormFieldRow {
                            TextField("Opis", text: $details, prompt: Text("np. Wejście na godzinę z biletu"), axis: .vertical)
                                .typography(.bodyRegular)
                                .foregroundStyle(.neutralInk)
                                .lineLimit(2...6)
                                .textInputAutocapitalization(.sentences)
                                .padding(.vertical, Spacing.s12)
                        }
                    }
                    FormCard(title: "Ikona") {
                        PlanIconPicker(selection: $icon)
                    }
                    PrimaryButton(title: point == nil ? "Dodaj punkt" : "Zapisz zmiany", isEnabled: canSave, action: save)
                        .padding(.top, Spacing.s12)
                    if point != nil {
                        Button("Usuń punkt", role: .destructive) { isConfirmingDelete = true }
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
            .navigationTitle(point == nil ? "Nowy punkt" : "Edytuj punkt")
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
            .confirmationDialog("Usunąć punkt?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Usuń punkt", role: .destructive, action: delete)
            } message: {
                Text("Punkt zniknie z planu dla wszystkich uczestników.")
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

    private func optionalText(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func save() {
        let request = PlanPointRequest(
            date: LocalDate(date, calendar: calendar),
            time: PlanTime(time, calendar: calendar),
            title: trimmedTitle,
            description: optionalText(details),
            place: optionalText(place),
            icon: icon
        )
        run { () async throws(APIError) in
            if let point {
                try await plans.update(point, with: request, in: trip)
            } else {
                try await plans.addPoint(request, to: trip)
            }
        }
    }

    private func delete() {
        guard let point else { return }
        run { () async throws(APIError) in try await plans.delete(point, from: trip) }
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
