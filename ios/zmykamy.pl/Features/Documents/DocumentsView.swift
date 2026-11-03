import QuickLook
import SwiftUI

private struct DocumentSheet: Identifiable {
    let id = UUID()
    var document: TripDocument?
}

struct DocumentsView: View {
    let trip: Trip
    let user: AuthUser

    @Environment(DocumentsStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var sheet: DocumentSheet?
    @State private var opener = DocumentOpener()
    @State private var documentToDelete: TripDocument?
    @State private var errorMessage = ""
    @State private var isShowingError = false

    var body: some View {
        content
            .background { theme.background.ignoresSafeArea() }
            .navigationTitle("Dokumenty")
            .navigationSubtitle(trip.name)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Dodaj dokument", image: .addRounded) { sheet = DocumentSheet() }
                        .disabled(store.isOffline(trip))
                }
            }
            .sheet(item: $sheet) { sheet in
                DocumentFormView(trip: trip, user: user, document: sheet.document)
            }
            .quickLookPreview($opener.previewURL)
            .confirmationDialog(
                "Usunąć dokument?",
                isPresented: Binding(get: { documentToDelete != nil }, set: { if !$0 { documentToDelete = nil } }),
                titleVisibility: .visible,
                presenting: documentToDelete
            ) { document in
                Button("Usuń „\(document.title)”", role: .destructive) { delete(document) }
            } message: { _ in
                Text("Dokument zniknie dla wszystkich uczestników.")
            }
            .alert("Coś poszło nie tak", isPresented: $isShowingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .task(id: trip.id) { try? await store.load(trip) }
    }

    @ViewBuilder
    private var content: some View {
        if let documents = store.documents(for: trip) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s8) {
                    Text(store.isOffline(trip) ? "Jesteś offline. Bilety i rezerwacje masz zapisane na telefonie." : "Bilety i rezerwacje dostępne również offline.")
                        .typography(.subheadRegular)
                        .foregroundStyle(store.isOffline(trip) ? AnyShapeStyle(.statusWarning) : AnyShapeStyle(.neutralGray))
                        .padding(.horizontal, Spacing.s6)
                        .padding(.bottom, Spacing.s12)

                    if documents.isEmpty {
                        ContentUnavailableView {
                            Label("Brak dokumentów", image: .description)
                        } description: {
                            Text("Dodaj bilety, rezerwacje albo ubezpieczenie, żeby cała ekipa miała je pod ręką.")
                        }
                        DashedAddButton(title: "Dodaj dokument") { sheet = DocumentSheet() }
                    }

                    ForEach(DocumentCategory.allCases) { category in
                        let items = documents.filter { $0.category == category }
                        if !items.isEmpty {
                            SectionLabel(text: category.sectionTitle)
                            ListCard(separatorInset: 62) {
                                ForEach(items) { document in
                                    row(document)
                                }
                            }
                            .padding(.bottom, Spacing.s16)
                        }
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

    private func row(_ document: TripDocument) -> some View {
        let isEditable = trip.canEdit(authoredBy: document.author, userID: user.id)
        return Button { open(document) } label: {
            DocumentRow(
                document: document,
                userID: user.id,
                isOffline: store.isAvailableOffline(document),
                isLoading: opener.loadingID == document.id
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if isEditable && !store.isOffline(trip) {
                Button("Edytuj", image: .edit) { sheet = DocumentSheet(document: document) }
                Button("Usuń", image: .delete, role: .destructive) { documentToDelete = document }
            }
        }
    }

    private func open(_ document: TripDocument) {
        Task {
            do throws(APIError) {
                try await opener.open(document, using: store)
            } catch {
                errorMessage = "Nie udało się otworzyć dokumentu. Sprawdź połączenie i spróbuj ponownie."
                isShowingError = true
            }
        }
    }

    private func delete(_ document: TripDocument) {
        Task {
            do throws(APIError) {
                try await store.delete(document, from: trip)
            } catch {
                errorMessage = error.localizedDescription
                isShowingError = true
            }
        }
    }
}

@Observable
final class DocumentOpener {
    var previewURL: URL?
    private(set) var loadingID: String?

    func open(_ document: TripDocument, using store: DocumentsStore) async throws(APIError) {
        switch document.kind {
        case .link:
            if let url = document.url {
                await UIApplication.shared.open(url)
            }
        case .file:
            loadingID = document.id
            defer { loadingID = nil }
            previewURL = try await store.localFile(for: document)
        }
    }
}

struct DocumentRow: View {
    let document: TripDocument
    let userID: String
    let isOffline: Bool
    var isLoading = false
    @Environment(\.theme) private var theme

    private var subtitle: String {
        let author = document.author.map { $0.userId == userID ? "Ty" : $0.name }
        return [document.typeLabel, author].compactMap(\.self).joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: Spacing.s12) {
            IconBadge(image: document.icon.resource, foreground: theme.accentStrong, background: theme.accentTint)
            VStack(alignment: .leading, spacing: 2) {
                Text(document.title)
                    .typography(.bodyEmphasis)
                    .foregroundStyle(.neutralInk)
                    .multilineTextAlignment(.leading)
                HStack(spacing: Spacing.s4) {
                    Text(subtitle)
                    if isOffline {
                        Image(.downloadDone)
                            .resizable()
                            .frame(width: 13, height: 13)
                            .accessibilityLabel("Dostępne offline")
                    }
                }
                .typography(.captionRegular)
                .foregroundStyle(.neutralGray)
            }
            Spacer(minLength: Spacing.s8)
            if isLoading {
                ProgressView()
            } else {
                Image(.chevronRight)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(.neutralGray3)
            }
        }
        .padding(.horizontal, Spacing.s14)
        .padding(.vertical, Spacing.s12)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
