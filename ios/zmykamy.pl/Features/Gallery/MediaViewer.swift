import AVKit
import Photos
import SwiftUI

struct MediaViewer: View {
    let trip: Trip
    let user: AuthUser
    let items: [MediaItem]

    @Environment(GalleryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selection: MediaItem.ID?
    @State private var sharedFile: SharedFile?
    @State private var isWorking = false
    @State private var isConfirmingDelete = false
    @State private var message: String?

    init(trip: Trip, user: AuthUser, items: [MediaItem], selection: MediaItem.ID) {
        self.trip = trip
        self.user = user
        self.items = items
        _selection = State(initialValue: selection)
    }

    private var current: MediaItem? {
        items.first { $0.id == selection }
    }

    private var canDelete: Bool {
        trip.isOrganizer || current?.uploadedBy?.userId == user.id
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $selection) {
                ForEach(items) { item in
                    MediaPage(item: item, isActive: item.id == selection)
                        .tag(Optional(item.id))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
        }
        .overlay(alignment: .top) { topBar }
        .overlay(alignment: .bottom) { bottomBar }
        .overlay {
            if let message {
                Text(message)
                    .typography(.calloutEmphasis)
                    .foregroundStyle(.neutralWhite)
                    .padding(.horizontal, Spacing.s16)
                    .padding(.vertical, Spacing.s12)
                    .background(.black.opacity(0.7), in: .capsule)
                    .transition(.opacity)
            }
        }
        .sheet(item: $sharedFile) { file in
            ShareSheet(items: [file.url])
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog("Usunąć z galerii?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Usuń", role: .destructive, action: delete)
        } message: {
            Text("Zniknie z galerii dla wszystkich uczestników.")
        }
        .onChange(of: items) { _, items in
            if items.isEmpty { dismiss() }
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(.close)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Zamknij")
            Spacer()
            Button(action: share) {
                Image(.iosShare)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .disabled(isWorking)
            .accessibilityLabel("Udostępnij")
        }
        .foregroundStyle(.neutralWhite)
        .padding(.horizontal, Spacing.gutter)
    }

    @ViewBuilder
    private var bottomBar: some View {
        if let current {
            HStack(spacing: Spacing.s12) {
                if let uploader = current.uploadedBy {
                    PersonAvatar(userID: uploader.userId, name: uploader.name, isViewer: uploader.userId == user.id, size: 38)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(current.uploadedBy.map { $0.userId == user.id ? "Ty" : $0.name } ?? "Uczestnik")
                        .typography(.bodyEmphasis)
                    Text(subtitle(for: current))
                        .typography(.footnote)
                        .opacity(0.8)
                }
                Spacer()
                Button(action: save) {
                    Image(.download)
                        .resizable()
                        .frame(width: 22, height: 22)
                        .frame(width: 40, height: 40)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(isWorking)
                .accessibilityLabel("Zapisz w Zdjęciach")
                if canDelete {
                    Button { isConfirmingDelete = true } label: {
                        Image(.delete)
                            .resizable()
                            .frame(width: 22, height: 22)
                            .frame(width: 40, height: 40)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorking)
                    .accessibilityLabel("Usuń")
                }
            }
            .foregroundStyle(.neutralWhite)
            .padding(.leading, Spacing.s12)
            .padding(.trailing, Spacing.s8)
            .frame(height: 62)
            .glassEffect(.regular.tint(.black.opacity(0.3)), in: .capsule)
            .padding(.horizontal, Spacing.gutter)
        }
    }

    private func subtitle(for item: MediaItem) -> String {
        let calendar = user.calendar
        let day = LocalDate(item.takenAt, calendar: calendar)
        let today = LocalDate(.now, calendar: calendar)
        let time = item.takenAt.formatted(.dateTime.hour().minute().locale(Locale(identifier: "pl_PL")))
        let date = day == today ? "Dziś" : TripDateFormat.dayMonth(day, calendar: calendar)
        return "\(date) · \(time)"
    }

    private func download(_ item: MediaItem) async -> URL? {
        guard let (temporary, _) = try? await URLSession.shared.download(from: item.url) else { return nil }
        let destination = FileManager.default.temporaryDirectory.appending(path: "\(item.id).\(item.fileExtension)")
        try? FileManager.default.removeItem(at: destination)
        return (try? FileManager.default.moveItem(at: temporary, to: destination)) != nil ? destination : nil
    }

    private func share() {
        guard let current else { return }
        isWorking = true
        Task {
            if let url = await download(current) {
                sharedFile = SharedFile(url: url)
            } else {
                show("Nie udało się pobrać pliku")
            }
            isWorking = false
        }
    }

    private func save() {
        guard let current else { return }
        isWorking = true
        Task {
            defer { isWorking = false }
            guard await PHPhotoLibrary.requestAuthorization(for: .addOnly) == .authorized else {
                show("Brak dostępu do Zdjęć")
                return
            }
            guard let url = await download(current) else {
                show("Nie udało się pobrać pliku")
                return
            }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    if current.kind == .video {
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                    } else {
                        PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                    }
                }
                show("Zapisano w Zdjęciach")
            } catch {
                show("Nie udało się zapisać")
            }
        }
    }

    private func delete() {
        guard let current else { return }
        let next = items.firstIndex(of: current).flatMap { index in
            items.indices.contains(index + 1) ? items[index + 1].id : index > 0 ? items[index - 1].id : nil
        }
        isWorking = true
        Task {
            do throws(APIError) {
                try await store.delete(current, from: trip)
                if let next {
                    selection = next
                } else {
                    dismiss()
                }
            } catch {
                show(error.localizedDescription)
            }
            isWorking = false
        }
    }

    private func show(_ text: String) {
        withAnimation { message = text }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { message = nil }
        }
    }
}

private struct SharedFile: Identifiable {
    let id = UUID()
    let url: URL
}

private struct MediaPage: View {
    let item: MediaItem
    let isActive: Bool
    @State private var player: AVPlayer?

    var body: some View {
        switch item.kind {
        case .photo:
            AsyncImage(url: item.url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .failure:
                    Image(.photoLibrary).foregroundStyle(.neutralGray)
                default:
                    AsyncImage(url: item.thumbnailUrl) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView().tint(.neutralWhite)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .video:
            VideoPlayer(player: player)
                .onAppear { player = player ?? AVPlayer(url: item.url) }
                .onChange(of: isActive) { _, active in
                    if !active { player?.pause() }
                }
                .onDisappear { player?.pause() }
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
