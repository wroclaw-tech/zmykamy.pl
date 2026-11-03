import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

private enum DocumentSource: String, CaseIterable, Identifiable {
    case file = "Plik"
    case link = "Link"

    var id: String { rawValue }
}

struct DocumentFormView: View {
    let trip: Trip
    let user: AuthUser
    var document: TripDocument?

    @Environment(DocumentsStore.self) private var store
    @Environment(PlanStore.self) private var plans
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var title: String
    @State private var category: DocumentCategory
    @State private var icon: PlanIcon
    @State private var planPointID: String?
    @State private var source: DocumentSource
    @State private var link: String
    @State private var file: PickedDocumentFile?
    @State private var fileName: String?
    @State private var photoItem: PhotosPickerItem?
    @State private var isImportingFile = false
    @State private var isSaving = false
    @State private var isConfirmingDelete = false
    @State private var errorMessage = ""
    @State private var isShowingError = false

    init(trip: Trip, user: AuthUser, document: TripDocument? = nil) {
        self.trip = trip
        self.user = user
        self.document = document
        _title = State(initialValue: document?.title ?? "")
        _category = State(initialValue: document?.category ?? .ticket)
        _icon = State(initialValue: document?.icon ?? DocumentCategory.ticket.defaultIcon)
        _planPointID = State(initialValue: document?.planPointId)
        _source = State(initialValue: document?.kind == .link ? .link : .file)
        _link = State(initialValue: document?.url?.absoluteString ?? "")
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var linkURL: URL? {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate), ["http", "https"].contains(url.scheme?.lowercased()), url.host() != nil else {
            return nil
        }
        return url
    }

    private var canSave: Bool {
        guard !trimmedTitle.isEmpty, !isSaving else { return false }
        switch source {
        case .file: return document != nil || file != nil
        case .link: return linkURL != nil
        }
    }

    private var points: [PlanPoint] {
        plans.plan(for: trip)?.points ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.s12) {
                    FormCard(title: "Co to?") {
                        FormFieldRow {
                            TextField("Nazwa", text: $title, prompt: Text("np. Karty pokładowe WAW → LIS"))
                                .typography(.bodyRegular)
                                .foregroundStyle(.neutralInk)
                                .textInputAutocapitalization(.sentences)
                        }
                        Picker("Rodzaj", selection: $category) {
                            ForEach(DocumentCategory.allCases) { category in
                                Text(category.title).tag(category)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    sourceCard
                    FormCard(title: "Punkt planu") {
                        Menu {
                            Button("Bez punktu") { planPointID = nil }
                            ForEach(points) { point in
                                Button("\(TripDateFormat.dayMonth(point.date, calendar: user.calendar)), \(point.time.text) · \(point.title)") {
                                    planPointID = point.id
                                }
                            }
                        } label: {
                            FormFieldRow {
                                Text(points.first { $0.id == planPointID }.map { "\($0.time.text) · \($0.title)" } ?? "Bez punktu")
                                    .typography(.bodyRegular)
                                    .foregroundStyle(planPointID == nil ? .neutralGray : .neutralInk)
                                    .lineLimit(1)
                                Spacer()
                                Image(.chevronRight)
                                    .resizable()
                                    .frame(width: 12, height: 12)
                                    .foregroundStyle(.neutralGray3)
                            }
                        }
                        .disabled(points.isEmpty)
                    }
                    FormCard(title: "Ikona") {
                        PlanIconPicker(selection: $icon)
                    }
                    PrimaryButton(title: document == nil ? "Dodaj dokument" : "Zapisz zmiany", isEnabled: canSave, action: save)
                        .padding(.top, Spacing.s12)
                    if document != nil {
                        Button("Usuń dokument", role: .destructive) { isConfirmingDelete = true }
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
            .navigationTitle(document == nil ? "Nowy dokument" : "Edytuj dokument")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(role: .confirm, action: save)
                            .disabled(!canSave)
                    }
                }
            }
            .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.pdf, .jpeg, .png]) { result in
                if case .success(let url) = result { importFile(url) }
            }
            .onChange(of: photoItem) { _, item in importPhoto(item) }
            .onChange(of: category) { old, new in
                if icon == old.defaultIcon { icon = new.defaultIcon }
            }
            .confirmationDialog("Usunąć dokument?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Usuń dokument", role: .destructive, action: delete)
            } message: {
                Text("Dokument zniknie dla wszystkich uczestników.")
            }
            .alert("Nie udało się zapisać", isPresented: $isShowingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .tint(theme.accent)
        .interactiveDismissDisabled(isSaving)
        .task { if plans.plan(for: trip) == nil { try? await plans.load(trip) } }
    }

    @ViewBuilder
    private var sourceCard: some View {
        FormCard(title: "Plik albo link") {
            if document == nil {
                Picker("Źródło", selection: $source) {
                    ForEach(DocumentSource.allCases) { source in
                        Text(source.rawValue).tag(source)
                    }
                }
                .pickerStyle(.segmented)
            }
            switch source {
            case .file:
                if let document {
                    FormFieldRow {
                        Image(.attachFile)
                            .resizable()
                            .frame(width: 18, height: 18)
                            .foregroundStyle(.neutralGray)
                        Text("\(document.typeLabel) dodany do wyjazdu")
                            .typography(.bodyRegular)
                            .foregroundStyle(.neutralInk)
                        Spacer()
                    }
                } else {
                    if let fileName {
                        FormFieldRow {
                            Image(.attachFile)
                                .resizable()
                                .frame(width: 18, height: 18)
                                .foregroundStyle(theme.accentStrong)
                            Text(fileName)
                                .typography(.bodyRegular)
                                .foregroundStyle(.neutralInk)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                        }
                    }
                    HStack(spacing: Spacing.s8) {
                        Button { isImportingFile = true } label: {
                            SourceButtonLabel(title: "PDF z plików", image: .description)
                        }
                        .buttonStyle(.plain)
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            SourceButtonLabel(title: "Zdjęcie", image: .photoLibrary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            case .link:
                FormFieldRow {
                    Image(.link)
                        .resizable()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(.neutralGray)
                    TextField("Link", text: $link, prompt: Text("https://"))
                        .typography(.bodyRegular)
                        .foregroundStyle(.neutralInk)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
        }
    }

    private func importFile(_ url: URL) {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
        let destination = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString)-\(url.lastPathComponent)")
        guard (try? FileManager.default.copyItem(at: url, to: destination)) != nil else { return }
        let type = UTType(filenameExtension: url.pathExtension)
        let contentType = type?.conforms(to: .pdf) == true ? "application/pdf" : type?.conforms(to: .png) == true ? "image/png" : "image/jpeg"
        file = PickedDocumentFile(url: destination, contentType: contentType)
        fileName = url.lastPathComponent
        if trimmedTitle.isEmpty {
            title = url.deletingPathExtension().lastPathComponent
        }
    }

    private func importPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpeg = image.jpegData(compressionQuality: 0.85) else { return }
            let destination = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).jpg")
            guard (try? jpeg.write(to: destination)) != nil else { return }
            file = PickedDocumentFile(url: destination, contentType: "image/jpeg")
            fileName = "Zdjęcie z biblioteki"
            photoItem = nil
        }
    }

    private func save() {
        let request = DocumentRequest(
            title: trimmedTitle,
            category: category,
            icon: icon,
            planPointId: planPointID,
            kind: source == .link && document == nil ? .link : nil,
            key: nil,
            contentType: nil,
            url: source == .link ? linkURL : nil
        )
        run { () async throws(APIError) in
            if let document {
                try await store.update(document, with: request, in: trip)
            } else if source == .link {
                try await store.addLink(request, to: trip)
            } else if let file {
                try await store.addFile(file, request: request, to: trip)
            }
        }
    }

    private func delete() {
        guard let document else { return }
        run { () async throws(APIError) in try await store.delete(document, from: trip) }
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

private struct SourceButtonLabel: View {
    let title: String
    let image: ImageResource
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.s6) {
            Image(image)
                .resizable()
                .frame(width: 18, height: 18)
            Text(title)
                .typography(.calloutEmphasis)
        }
        .foregroundStyle(theme.accentStrong)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(theme.accentTint, in: .rect(cornerRadius: Radius.sm))
    }
}
