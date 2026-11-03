import SwiftUI

struct NoteFormView: View {
    let trip: Trip
    var note: TripNote?

    @Environment(DocumentsStore.self) private var store
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var title: String
    @State private var text: String
    @State private var pinned: Bool
    @State private var isSaving = false
    @State private var isConfirmingDelete = false
    @State private var errorMessage = ""
    @State private var isShowingError = false

    init(trip: Trip, note: TripNote? = nil) {
        self.trip = trip
        self.note = note
        _title = State(initialValue: note?.title ?? "")
        _text = State(initialValue: note?.text ?? "")
        _pinned = State(initialValue: note?.pinned ?? false)
    }

    private var userID: String? {
        auth.user?.id
    }

    private var isEditable: Bool {
        note == nil || trip.isOrganizer || note?.author?.userId == userID
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        isEditable && !trimmedTitle.isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s12) {
                    VStack(alignment: .leading, spacing: Spacing.s12) {
                        TextField("Tytuł", text: $title, prompt: Text("Tytuł, np. Kod do drzwi"))
                            .typography(.headline)
                            .foregroundStyle(.neutralInk)
                            .textInputAutocapitalization(.sentences)
                        Rectangle()
                            .fill(.alphaSeparator)
                            .frame(height: 1)
                        TextField("Treść", text: $text, prompt: Text("Co warto zapamiętać?"), axis: .vertical)
                            .typography(.bodyRegular)
                            .foregroundStyle(.neutralInk)
                            .lineLimit(4...14)
                            .textInputAutocapitalization(.sentences)
                    }
                    .padding(Spacing.s16)
                    .background(.neutralWhite, in: .rect(cornerRadius: Radius.xl))

                    ListCard {
                        HStack(spacing: Spacing.s12) {
                            IconBadge(image: .keep, foreground: theme.accentStrong, background: theme.accentTint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Przypnij na górze wyjazdu")
                                    .typography(.bodyRegular)
                                    .foregroundStyle(.neutralInk)
                                Text("Każdy zobaczy ją jako pierwszą")
                                    .typography(.captionRegular)
                                    .foregroundStyle(.neutralGray)
                            }
                            Spacer()
                            Toggle("Przypnij na górze wyjazdu", isOn: $pinned)
                                .labelsHidden()
                        }
                        .padding(.horizontal, Spacing.s14)
                        .padding(.vertical, Spacing.s12)
                    }

                    if pinned && !trimmedTitle.isEmpty {
                        SectionLabel(text: "PODGLĄD NA EKRANIE WYJAZDU")
                            .padding(.top, Spacing.s8)
                        VStack(alignment: .leading, spacing: Spacing.s4) {
                            HStack(spacing: Spacing.s4) {
                                Image(.keep)
                                    .resizable()
                                    .frame(width: 14, height: 14)
                                Text("Przypięte")
                                    .typography(.captionEmphasis)
                            }
                            .foregroundStyle(.statusWarning)
                            Text(trimmedTitle)
                                .typography(.bodyEmphasis)
                                .foregroundStyle(.neutralInk)
                            if !text.isEmpty {
                                Text(text)
                                    .typography(.subheadRegular)
                                    .foregroundStyle(.neutralInk2)
                                    .lineLimit(2)
                            }
                        }
                        .padding(Spacing.s16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.statusWarningTint, in: .rect(cornerRadius: Radius.xl))
                    }

                    if note != nil && isEditable {
                        Button("Usuń notatkę", role: .destructive) { isConfirmingDelete = true }
                            .typography(.bodyEmphasis)
                            .foregroundStyle(.statusDanger)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .padding(.top, Spacing.s12)
                            .disabled(isSaving)
                    }
                }
                .disabled(!isEditable)
                .padding(.horizontal, Spacing.gutter)
                .padding(.top, Spacing.s12)
                .padding(.bottom, Spacing.s24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { theme.background.ignoresSafeArea() }
            .navigationTitle(note == nil ? "Nowa notatka" : isEditable ? "Edytuj notatkę" : "Notatka")
            .navigationSubtitle(trip.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                if isEditable {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(role: .confirm, action: save)
                            .disabled(!canSave)
                    }
                }
            }
            .confirmationDialog("Usunąć notatkę?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Usuń notatkę", role: .destructive, action: delete)
            } message: {
                Text("Notatka zniknie dla wszystkich uczestników.")
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

    private func save() {
        let request = NoteRequest(
            title: trimmedTitle,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            pinned: pinned
        )
        run { () async throws(APIError) in
            if let note {
                try await store.update(note, with: request, in: trip)
            } else {
                try await store.addNote(request, to: trip)
            }
        }
    }

    private func delete() {
        guard let note else { return }
        run { () async throws(APIError) in try await store.delete(note, from: trip) }
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
