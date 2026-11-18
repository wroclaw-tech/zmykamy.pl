import PhotosUI
import SwiftUI

private struct ViewerSelection: Identifiable {
    let id: MediaItem.ID
}

struct GalleryView: View {
    let trip: Trip
    let user: AuthUser

    @Environment(GalleryStore.self) private var store
    @Environment(GooglePhotosImporter.self) private var googlePhotos
    @Environment(PlanStore.self) private var plans
    @Environment(\.theme) private var theme
    @State private var filter = GalleryFilter.all
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isShowingPicker = false
    @State private var isShowingCamera = false
    @State private var isShowingGooglePhotos = false
    @State private var isImporting = false
    @State private var viewer: ViewerSelection?
    @State private var loadError: String?
    @State private var isShowingRefreshError = false

    private var calendar: Calendar {
        user.calendar
    }

    var body: some View {
        NavigationStack {
            content
                .background { theme.background.ignoresSafeArea() }
                .navigationTitle("Galeria")
                .navigationSubtitle(trip.name)
                .toolbar {
                    CloseTripButton()
                    ToolbarItem(placement: .topBarTrailing) {
                        addMenu
                    }
                }
                .photosPicker(
                    isPresented: $isShowingPicker,
                    selection: $pickerItems,
                    maxSelectionCount: 30,
                    matching: .any(of: [.images, .videos]),
                    preferredItemEncoding: .compatible
                )
                .navigationDestination(isPresented: $isShowingGooglePhotos) {
                    GooglePhotosImportView(trip: trip)
                }
                .fullScreenCover(isPresented: $isShowingCamera) {
                    CameraPicker { captured in importCaptured(captured) }
                        .ignoresSafeArea()
                }
                .fullScreenCover(item: $viewer) { selection in
                    MediaViewer(
                        trip: trip,
                        user: user,
                        items: filteredItems,
                        selection: selection.id
                    )
                }
                .alert("Nie udało się odświeżyć", isPresented: $isShowingRefreshError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(loadError ?? "")
                }
        }
        .task(id: trip.id) { await load() }
        .onChange(of: pickerItems) { _, items in importPicked(items) }
    }

    private var filteredItems: [MediaItem] {
        (store.media(for: trip) ?? []).filter(filter.includes)
    }

    private var googlePhotosProgress: String? {
        guard case .downloading(let done, let total) = googlePhotos.phase(for: trip) else { return nil }
        return "Google Photos · \(min(done + 1, total)) z \(total)"
    }

    private var addMenu: some View {
        Menu {
            Button("Wybierz z biblioteki", image: .photoLibrary) { isShowingPicker = true }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Zrób zdjęcie lub film", image: .photoCamera) { isShowingCamera = true }
            }
            if googlePhotos.oauth != nil {
                Button("Importuj z Google Photos", image: .download) { isShowingGooglePhotos = true }
            }
        } label: {
            Image(.addPhotoAlternate)
        }
        .accessibilityLabel("Dodaj zdjęcia")
    }

    @ViewBuilder
    private var content: some View {
        if let items = store.media(for: trip) {
            let uploads = store.uploads(for: trip)
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s16) {
                    HStack {
                        Picker("Rodzaj", selection: $filter) {
                            ForEach(GalleryFilter.allCases) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal, Spacing.gutter)

                    Text(GalleryFormat.counts(items))
                        .typography(.subheadRegular)
                        .foregroundStyle(.neutralGray)
                        .padding(.horizontal, Spacing.gutter)

                    if isImporting || !uploads.isEmpty || googlePhotosProgress != nil {
                        uploadsSection(uploads)
                    }

                    if items.isEmpty && uploads.isEmpty && !isImporting {
                        emptyState
                    } else if filteredItems.isEmpty {
                        Text(filter == .videos ? "Nie ma jeszcze filmów." : "Nie ma jeszcze zdjęć.")
                            .typography(.calloutRegular)
                            .foregroundStyle(.neutralGray)
                            .padding(.horizontal, Spacing.gutter)
                    }

                    ForEach(GalleryDay.group(filteredItems, calendar: calendar)) { day in
                        daySection(day)
                    }
                }
                .padding(.bottom, Spacing.s24)
            }
            .refreshable { await refresh() }
        } else if let loadError {
            ContentUnavailableView {
                Label("Nie udało się wczytać galerii", image: .photoLibrary)
            } description: {
                Text(loadError)
            } actions: {
                Button("Spróbuj ponownie") { Task { await load() } }
                    .buttonStyle(.glassProminent)
            }
        } else {
            ProgressView()
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.s12) {
            ContentUnavailableView {
                Label("Brak zdjęć", image: .photoLibrary)
            } description: {
                Text("Dodaj zdjęcia i filmy z wyjazdu, żeby cała ekipa miała je w jednym miejscu.")
            }
            DashedAddButton(title: "Dodaj z biblioteki") { isShowingPicker = true }
                .padding(.horizontal, Spacing.gutter)
        }
    }

    private func uploadsSection(_ uploads: [GalleryStore.Upload]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            HStack(spacing: Spacing.s8) {
                Text("Wysyłanie")
                    .typography(.title3)
                    .foregroundStyle(.neutralInk)
                if isImporting {
                    ProgressView()
                }
                if let googlePhotosProgress {
                    Spacer(minLength: Spacing.s8)
                    Button(googlePhotosProgress) { isShowingGooglePhotos = true }
                        .typography(.subheadRegular)
                        .foregroundStyle(.neutralGray)
                }
            }
            .padding(.horizontal, Spacing.gutter)
            GalleryMosaic(items: uploads) { upload, size in
                UploadTile(upload: upload, size: size)
                    .onTapGesture { if upload.isFailed { store.retry(upload) } }
                    .contextMenu {
                        if upload.isFailed {
                            Button("Ponów", image: .refresh) { store.retry(upload) }
                            Button("Usuń", role: .destructive) { store.discard(upload) }
                        }
                    }
            }
        }
    }

    private func daySection(_ day: GalleryDay) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s8) {
                Text(dayTitle(day.date))
                    .typography(.title3)
                    .foregroundStyle(.neutralInk)
                if let places = GalleryFormat.places(on: day.date, in: plans.plan(for: trip)) {
                    Text(places)
                        .typography(.subheadRegular)
                        .foregroundStyle(.neutralGray)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.s8)
            GalleryMosaic(items: day.items) { item, size in
                Button { viewer = ViewerSelection(id: item.id) } label: {
                    MediaTile(item: item, size: size, viewerID: user.id)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func dayTitle(_ date: LocalDate) -> String {
        let today = LocalDate(.now, calendar: calendar)
        if date == today { return "Dziś" }
        if date == today.adding(days: -1, calendar: calendar) { return "Wczoraj" }
        let text = date.date(in: calendar).formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "pl_PL")))
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    private func importPicked(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        pickerItems = []
        isImporting = true
        Task {
            var prepared: [PreparedMedia] = []
            for item in items {
                if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                    if let movie = try? await item.loadTransferable(type: PickedMovie.self),
                       let media = await MediaImport.video(at: movie.url) {
                        prepared.append(media)
                    }
                } else if let data = try? await item.loadTransferable(type: Data.self),
                          let media = await MediaImport.photo(from: data) {
                    prepared.append(media)
                }
            }
            store.enqueue(prepared, to: trip)
            isImporting = false
        }
    }

    private func importCaptured(_ captured: CameraPicker.Capture) {
        isImporting = true
        Task {
            let media: PreparedMedia? = switch captured {
            case .photo(let image): await MediaImport.photo(from: image)
            case .video(let url): await MediaImport.video(at: url)
            }
            if let media {
                store.enqueue([media], to: trip)
            }
            isImporting = false
        }
    }

    private func load() async {
        loadError = nil
        do throws(APIError) {
            try await store.load(trip)
        } catch {
            loadError = error.localizedDescription
        }
        if plans.plan(for: trip) == nil {
            try? await plans.load(trip)
        }
    }

    private func refresh() async {
        do throws(APIError) {
            try await store.load(trip)
        } catch {
            loadError = error.localizedDescription
            isShowingRefreshError = true
        }
    }
}
