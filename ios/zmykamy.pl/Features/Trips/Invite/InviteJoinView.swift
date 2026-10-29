import SwiftUI

struct InviteJoinView: View {
    let code: String
    let onJoined: (Trip) -> Void
    @Environment(TripsStore.self) private var trips
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    private enum Phase {
        case loading
        case ready(InvitePreview)
        case invalid
        case failed(String)
    }

    @State private var phase = Phase.loading
    @State private var isJoining = false
    @State private var errorMessage = ""
    @State private var isShowingError = false

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background { theme.background.ignoresSafeArea() }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Zamknij", image: .close) { dismiss() }
                    }
                }
        }
        .task { await loadPreview() }
        .alert("Nie udało się dołączyć", isPresented: $isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            ProgressView()
        case .ready(let preview):
            ready(preview)
        case .invalid:
            ContentUnavailableView {
                Label("Zaproszenie nie jest już ważne", image: .flightTakeoff)
            } description: {
                Text("Poproś organizatora o nowy link.")
            }
        case .failed(let message):
            ContentUnavailableView {
                Label("Nie udało się wczytać zaproszenia", image: .flightTakeoff)
            } description: {
                Text(message)
            } actions: {
                Button("Spróbuj ponownie") { Task { await loadPreview() } }
                    .buttonStyle(.glassProminent)
            }
        }
    }

    private func ready(_ preview: InvitePreview) -> some View {
        VStack(spacing: Spacing.s24) {
            VStack(spacing: Spacing.s8) {
                Text("Zaproszenie do wyjazdu")
                    .typography(.sectionLabel)
                    .foregroundStyle(.neutralGray)
                Text(preview.name)
                    .typography(.title1)
                    .foregroundStyle(.neutralInk)
                    .multilineTextAlignment(.center)
                Text(details(of: preview))
                    .typography(.calloutRegular)
                    .foregroundStyle(.neutralGray)
                    .multilineTextAlignment(.center)
            }
            Button {
                join()
            } label: {
                Text("Dołącz do wyjazdu")
                    .typography(.bodyEmphasis)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(isJoining)
        }
        .padding(.horizontal, Spacing.s24)
    }

    private func details(of preview: InvitePreview) -> String {
        [
            TripDateFormat.range(preview.startDate, preview.endDate),
            preview.destination.flatMap { $0.name == preview.name ? $0.country : $0.name },
            preview.organizerName.map { "Organizator: \($0)" },
            Self.peopleCount(preview.memberCount),
        ]
        .compactMap(\.self)
        .joined(separator: "\n")
    }

    private static func peopleCount(_ count: Int) -> String {
        let lastDigit = count % 10
        let isFewForm = (2...4).contains(lastDigit) && !(12...14).contains(count % 100)
        if count == 1 { return "1 osoba w ekipie" }
        return "\(count) \(isFewForm ? "osoby" : "osób") w ekipie"
    }

    private func loadPreview() async {
        phase = .loading
        do throws(APIError) {
            let preview = try await trips.preview(inviteCode: code)
            if let existing = trips.trip(id: preview.tripId) {
                onJoined(existing)
                dismiss()
            } else {
                phase = .ready(preview)
            }
        } catch .notFound {
            phase = .invalid
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func join() {
        isJoining = true
        Task {
            do throws(APIError) {
                onJoined(try await trips.join(inviteCode: code))
                dismiss()
            } catch .notFound {
                phase = .invalid
            } catch {
                errorMessage = error.localizedDescription
                isShowingError = true
            }
            isJoining = false
        }
    }
}
