import SwiftUI

private struct TripHeader: View {
    let trip: Trip
    let viewerID: String

    private var subtitle: String {
        let place = trip.destination.flatMap { $0.name == trip.name ? $0.country : $0.name }
        return [TripDateFormat.range(trip.startDate, trip.endDate), place].compactMap(\.self).joined(separator: " · ")
    }

    var body: some View {
        TripCover(url: trip.coverUrl)
            .frame(height: 330)
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [Color(red: 0.157, green: 0.086, blue: 0.125).opacity(0), Color(red: 0.157, green: 0.086, blue: 0.125).opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 170)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: Spacing.s12) {
                    VStack(alignment: .leading, spacing: Spacing.s6) {
                        Text(trip.name)
                            .typography(.displayCountdown)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                        Text(subtitle)
                            .typography(.calloutRegular)
                    }
                    .foregroundStyle(.neutralWhite)
                    Spacer(minLength: 0)
                    MemberAvatarStack(members: trip.members, viewerID: viewerID, size: 28, borderColor: .neutralWhite.opacity(0.9))
                        .padding(.bottom, 2)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 44)
            }
    }
}

private struct CountdownCard: View {
    let trip: Trip
    let today: LocalDate
    @Environment(\.theme) private var theme

    private static let number = Typography(size: 58, weight: .heavy, tracking: -2.5)
    private static let unit = Typography(size: 17, weight: .semibold)

    var body: some View {
        HStack(alignment: .center) {
            switch trip.phase(on: today) {
            case .upcoming(let daysLeft):
                HStack(alignment: .firstTextBaseline, spacing: Spacing.s6) {
                    Text("za")
                        .typography(Self.unit)
                        .foregroundStyle(.neutralGray)
                    Text("\(daysLeft)")
                        .typography(Self.number)
                        .foregroundStyle(theme.accent)
                    Text(daysLeft == 1 ? "dzień" : "dni")
                        .typography(Self.unit)
                        .foregroundStyle(.neutralGray)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("Wyjazd \(TripDateFormat.weekdayPhrase(trip.startDate))")
                        .typography(.subheadRegular)
                        .foregroundStyle(.neutralInk2)
                    Text(TripDateFormat.dayMonth(trip.startDate))
                        .typography(Typography(size: 14, weight: .bold))
                        .foregroundStyle(.neutralInk)
                }
            case .ongoing(let day, let total):
                VStack(alignment: .leading, spacing: 0) {
                    Text("Dzień")
                        .typography(.calloutRegular)
                        .foregroundStyle(.neutralGray)
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("\(day)")
                            .foregroundStyle(theme.accent)
                        Text("/\(total)")
                            .foregroundStyle(.neutralGray3)
                    }
                    .typography(Self.number)
                }
                Spacer()
            case .past:
                Text("Wyjazd zakończony")
                    .typography(.headline)
                    .foregroundStyle(.neutralGray)
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, Spacing.s12)
        .frame(minHeight: 94)
        .background(.neutralWhite, in: .rect(cornerRadius: 28))
        .shadow(color: .neutralBlack.opacity(0.08), radius: 15, y: 10)
        .accessibilityElement(children: .combine)
    }
}

private struct TripToolTile: View {
    let title: String
    let detail: String
    let image: ImageResource
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.s12) {
            IconBadge(image: image, foreground: theme.accentStrong, background: theme.accentTint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .typography(.bodyEmphasis)
                    .foregroundStyle(.neutralInk)
                Text(detail)
                    .typography(.captionRegular)
                    .foregroundStyle(.neutralGray)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.s14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.neutralWhite, in: .rect(cornerRadius: Radius.lg))
        .contentShape(.rect(cornerRadius: Radius.lg))
    }
}

struct TripOverviewView: View {
    let trip: Trip
    let user: AuthUser
    @Environment(TripsStore.self) private var trips
    @Environment(DocumentsStore.self) private var documents
    @Environment(\.theme) private var theme
    @State private var isShowingNotes = false
    @State private var isEditing = false
    @State private var isConfirmingDelete = false
    @State private var isDeleting = false
    @State private var errorMessage = ""
    @State private var isShowingError = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TripHeader(trip: trip, viewerID: user.id)
                CountdownCard(trip: trip, today: LocalDate(.now))
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.top, -28)
                tools
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.top, Spacing.s16)
            }
            .padding(.bottom, Spacing.s24)
        }
        .ignoresSafeArea(edges: .top)
        .background { theme.background.ignoresSafeArea() }
        .navigationDestination(isPresented: $isShowingNotes) {
            NotesView(trip: trip, user: user)
        }
        .task(id: trip.id) { try? await documents.load(trip) }
        .toolbar {
            if trip.isOrganizer {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Edytuj") { isEditing = true }
                        Button("Usuń wyjazd", role: .destructive) { isConfirmingDelete = true }
                    } label: {
                        Image(.moreHoriz)
                    }
                    .accessibilityLabel("Więcej")
                    .disabled(isDeleting)
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            TripFormView(user: user, trip: trip)
        }
        .confirmationDialog("Usunąć wyjazd?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Usuń wyjazd", role: .destructive, action: delete)
        } message: {
            Text("Wyjazd zniknie dla wszystkich uczestników. Tego nie da się cofnąć.")
        }
        .alert("Nie udało się usunąć", isPresented: $isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var tools: some View {
        let pinned = (documents.notes(for: trip) ?? []).filter(\.pinned)
        let documentCount = documents.documents(for: trip)?.count ?? 0
        let noteCount = documents.notes(for: trip)?.count ?? 0
        return VStack(alignment: .leading, spacing: Spacing.s12) {
            if !pinned.isEmpty {
                PinnedNotesCard(notes: pinned, userID: user.id, isCompact: true) { _ in isShowingNotes = true }
            }
            HStack(spacing: Spacing.s12) {
                NavigationLink {
                    DocumentsView(trip: trip, user: user)
                } label: {
                    TripToolTile(
                        title: "Dokumenty",
                        detail: documentCount == 0 ? "Bilety, rezerwacje" : PolishPlural.form(documentCount, one: "1 plik", few: "\(documentCount) pliki", many: "\(documentCount) plików"),
                        image: .description
                    )
                }
                .buttonStyle(.plain)
                NavigationLink {
                    NotesView(trip: trip, user: user)
                } label: {
                    TripToolTile(
                        title: "Notatki",
                        detail: noteCount == 0 ? "Kody, Wi‑Fi, numery" : PolishPlural.form(noteCount, one: "1 notatka", few: "\(noteCount) notatki", many: "\(noteCount) notatek"),
                        image: .eventNote
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func delete() {
        isDeleting = true
        Task {
            do throws(APIError) {
                try await trips.delete(trip)
            } catch {
                errorMessage = error.localizedDescription
                isShowingError = true
            }
            isDeleting = false
        }
    }
}
