import SwiftUI

private struct NoteSheet: Identifiable {
    let id = UUID()
    var note: TripNote?
}

struct NotesView: View {
    let trip: Trip
    let user: AuthUser

    @Environment(DocumentsStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var sheet: NoteSheet?

    var body: some View {
        content
            .background { theme.background.ignoresSafeArea() }
            .navigationTitle("Notatki")
            .navigationSubtitle(trip.name)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Nowa notatka", image: .addRounded) { sheet = NoteSheet() }
                        .disabled(store.isOffline(trip))
                }
            }
            .sheet(item: $sheet) { sheet in
                NoteFormView(trip: trip, note: sheet.note)
            }
            .task(id: trip.id) { try? await store.load(trip) }
    }

    @ViewBuilder
    private var content: some View {
        if let notes = store.notes(for: trip) {
            let pinned = notes.filter(\.pinned)
            let others = notes.filter { !$0.pinned }
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s8) {
                    if notes.isEmpty {
                        ContentUnavailableView {
                            Label("Brak notatek", image: .eventNote)
                        } description: {
                            Text("Zapisz kod do drzwi, hasło do Wi‑Fi albo numer do gospodarza.")
                        }
                        DashedAddButton(title: "Nowa notatka") { sheet = NoteSheet() }
                    }
                    if !pinned.isEmpty {
                        SectionLabel(text: "PRZYPIĘTE · WIDOCZNE NA GÓRZE WYJAZDU")
                        PinnedNotesCard(notes: pinned, userID: user.id) { note in open(note) }
                            .padding(.bottom, Spacing.s16)
                    }
                    if !others.isEmpty {
                        SectionLabel(text: "POZOSTAŁE · \(others.count)")
                        ListCard(separatorInset: 60) {
                            ForEach(others) { note in
                                Button { open(note) } label: {
                                    NoteRow(note: note, userID: user.id)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if !notes.isEmpty {
                        Text("Przypięte notatki każdy uczestnik widzi na ekranie wyjazdu, także bez internetu.")
                            .typography(.footnote)
                            .foregroundStyle(.neutralGray)
                            .padding(.horizontal, Spacing.s6)
                            .padding(.top, Spacing.s8)
                    }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.bottom, Spacing.s24)
            }
            .refreshable { try? await store.load(trip) }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func open(_ note: TripNote) {
        guard !store.isOffline(trip) else { return }
        sheet = NoteSheet(note: note)
    }
}

struct PinnedNotesCard: View {
    let notes: [TripNote]
    let userID: String
    var isCompact = false
    let onTap: (TripNote) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                if index > 0 {
                    Rectangle()
                        .fill(.statusWarning.opacity(0.15))
                        .frame(height: 0.5)
                }
                Button { onTap(note) } label: {
                    PinnedNoteRow(note: note, userID: userID, isCompact: isCompact)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.statusWarningTint, in: .rect(cornerRadius: Radius.xl))
    }
}

private struct PinnedNoteRow: View {
    let note: TripNote
    let userID: String
    let isCompact: Bool

    private var footer: String {
        let author = note.author.map { $0.userId == userID ? "Ty" : $0.name }
        return [author, NoteFormat.relative(note.updatedDate)].compactMap(\.self).joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            HStack(alignment: .top) {
                Text(note.title)
                    .typography(.subheadEmphasis)
                    .foregroundStyle(.statusWarning)
                Spacer()
                Image(.keep)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(.statusWarning)
                    .accessibilityHidden(true)
            }
            if !note.text.isEmpty {
                Text(note.text)
                    .typography(note.isCode ? Typography(size: 20, weight: .semibold) : .bodyRegular)
                    .monospaced(note.isCode)
                    .foregroundStyle(.neutralInk)
                    .lineLimit(isCompact ? 3 : nil)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
            }
            if !isCompact {
                Text(footer)
                    .typography(.captionRegular)
                    .foregroundStyle(.neutralGray)
            }
        }
        .padding(.horizontal, Spacing.s16)
        .padding(.vertical, Spacing.s14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

private struct NoteRow: View {
    let note: TripNote
    let userID: String
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s12) {
            IconBadge(image: .eventNote, foreground: theme.accentStrong, background: theme.accentTint)
            VStack(alignment: .leading, spacing: 2) {
                Text(note.title)
                    .typography(.bodyEmphasis)
                    .foregroundStyle(.neutralInk)
                if !note.text.isEmpty {
                    Text(note.text)
                        .typography(.subheadRegular)
                        .foregroundStyle(.neutralGray)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: Spacing.s8)
            if let author = note.author {
                PersonAvatar(userID: author.userId, name: author.name, isViewer: author.userId == userID, size: 26)
            }
        }
        .padding(.horizontal, Spacing.s14)
        .padding(.vertical, Spacing.s12)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
