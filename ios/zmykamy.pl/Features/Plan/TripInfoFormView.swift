import SwiftUI

private struct InfoPreset: Identifiable {
    let title: String
    let icon: PlanIcon

    var id: String { title }

    static let all = [
        InfoPreset(title: "Nocleg", icon: .bed),
        InfoPreset(title: "Dojazd", icon: .flight),
        InfoPreset(title: "Na miejscu", icon: .tram),
        InfoPreset(title: "Wspólna kasa", icon: .savings),
    ]
}

/// Adds a general info card, or edits one when `card` is given.
struct TripInfoFormView: View {
    let trip: Trip
    var card: TripInfoCard?

    @Environment(PlanStore.self) private var plans
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var title: String
    @State private var text: String
    @State private var icon: PlanIcon
    @State private var isSaving = false
    @State private var isConfirmingDelete = false
    @State private var errorMessage = ""
    @State private var isShowingError = false

    init(trip: Trip, card: TripInfoCard? = nil) {
        self.trip = trip
        self.card = card
        _title = State(initialValue: card?.title ?? "")
        _text = State(initialValue: card?.text ?? "")
        _icon = State(initialValue: card?.icon ?? .info)
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
                    if card == nil {
                        presetsCard
                    }
                    FormCard(title: "Tytuł") {
                        FormFieldRow {
                            TextField("Tytuł", text: $title, prompt: Text("np. Nocleg"))
                                .typography(.bodyRegular)
                                .foregroundStyle(.neutralInk)
                                .textInputAutocapitalization(.sentences)
                        }
                    }
                    FormCard(title: "Treść") {
                        FormFieldRow {
                            TextField("Treść", text: $text, prompt: Text("np. Mieszkanie w Alfamie, Rua dos Remédios 4"), axis: .vertical)
                                .typography(.bodyRegular)
                                .foregroundStyle(.neutralInk)
                                .lineLimit(4...12)
                                .textInputAutocapitalization(.sentences)
                                .padding(.vertical, Spacing.s12)
                        }
                    }
                    FormCard(title: "Ikona") {
                        PlanIconPicker(selection: $icon)
                    }
                    PrimaryButton(title: card == nil ? "Dodaj informację" : "Zapisz zmiany", isEnabled: canSave, action: save)
                        .padding(.top, Spacing.s12)
                    if card != nil {
                        Button("Usuń informację", role: .destructive) { isConfirmingDelete = true }
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
            .navigationTitle(card == nil ? "Nowa informacja" : "Edytuj informację")
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
            .confirmationDialog("Usunąć informację?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Usuń informację", role: .destructive, action: delete)
            } message: {
                Text("Informacja zniknie dla wszystkich uczestników.")
            }
            .alert("Nie udało się zapisać", isPresented: $isShowingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .tint(theme.accent)
        .interactiveDismissDisabled(isSaving)
    }

    private var presetsCard: some View {
        FormCard(title: "Szybki start") {
            HStack(spacing: Spacing.s8) {
                ForEach(InfoPreset.all) { preset in
                    Button {
                        title = preset.title
                        icon = preset.icon
                    } label: {
                        Text(preset.title)
                            .typography(.captionEmphasis)
                            .foregroundStyle(theme.accentStrong)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, Spacing.s8)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(theme.accentTint, in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func save() {
        let request = TripInfoRequest(
            title: trimmedTitle,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: icon
        )
        run { () async throws(APIError) in
            if let card {
                try await plans.update(card, with: request, in: trip)
            } else {
                try await plans.addInfo(request, to: trip)
            }
        }
    }

    private func delete() {
        guard let card else { return }
        run { () async throws(APIError) in try await plans.delete(card, from: trip) }
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
