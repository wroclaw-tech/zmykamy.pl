import SwiftUI

private struct FeaturedTripCard: View {
    let trip: Trip
    let viewerID: String
    let today: LocalDate

    private var status: (icon: ImageResource, text: String) {
        switch trip.phase(on: today) {
        case .ongoing(let day, let total): (.sunny, "Trwa · dzień \(day) z \(total)")
        case .upcoming(let daysLeft): (.hourglassTop, "Za \(PolishPlural.days(daysLeft))")
        case .past: (.checkCircle, "Zakończony")
        }
    }

    private var subtitle: String {
        let place = trip.destination.map { $0.country ?? $0.name }
        return [TripDateFormat.range(trip.startDate, trip.endDate), place].compactMap(\.self).joined(separator: " · ")
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 34)
        TripCover(url: trip.coverUrl)
            .frame(height: 380)
            .overlay(alignment: .topLeading) {
                HStack(spacing: Spacing.s6) {
                    Image(status.icon)
                    Text(status.text)
                        .typography(.subheadEmphasis)
                        .foregroundStyle(.neutralInk)
                }
                .padding(.horizontal, Spacing.s14)
                .frame(height: 34)
                .glassEffect(.regular, in: .capsule)
                .padding(Spacing.s14)
            }
            .overlay(alignment: .bottom) {
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.s4) {
                        Text(trip.name)
                            .typography(.title1)
                        Text(subtitle)
                            .typography(.calloutRegular)
                            .foregroundStyle(.neutralInk2)
                        HStack(spacing: Spacing.s8) {
                            MemberAvatarStack(members: trip.members, viewerID: viewerID)
                            Text(PolishPlural.people(trip.members.count))
                                .typography(.subheadRegular)
                                .foregroundStyle(.neutralInk2)
                        }
                        .padding(.top, Spacing.s6)
                    }
                    .foregroundStyle(.neutralInk)
                    Spacer()
                    Image(.chevronRight)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.neutralGray)
                }
                .padding(18)
                .glassEffect(.regular, in: .rect(cornerRadius: Radius.xl))
                .padding(10)
            }
            .clipShape(shape)
            .contentShape(shape)
            .shadow(color: Color(red: 0.369, green: 0.227, blue: 0.314).opacity(0.22), radius: 15, y: 14)
            .accessibilityElement(children: .combine)
    }
}

private struct TripRow: View {
    let trip: Trip
    let today: LocalDate
    @Environment(\.theme) private var theme

    private var subtitle: String {
        let isPast = trip.phase(on: today) == .past
        let dates = TripDateFormat.shortRange(trip.startDate, trip.endDate, includesYear: isPast)
        return "\(dates) · \(trip.members.count) os."
    }

    var body: some View {
        HStack(spacing: 14) {
            TripCover(url: trip.coverUrl)
                .frame(width: 54, height: 54)
                .clipShape(.rect(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.name)
                    .typography(Typography(size: 17, weight: .semibold))
                    .foregroundStyle(.neutralInk)
                Text(subtitle)
                    .typography(.subheadRegular)
                    .foregroundStyle(.neutralGray)
            }
            Spacer(minLength: Spacing.s8)
            badge
        }
        .padding(.horizontal, 14)
        .padding(.vertical, Spacing.s12)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var badge: some View {
        switch trip.phase(on: today) {
        case .upcoming(let daysLeft):
            badgeLabel("za \(PolishPlural.days(daysLeft))")
        case .ongoing:
            badgeLabel("trwa")
        case .past:
            EmptyView()
        }
    }

    private func badgeLabel(_ text: String) -> some View {
        Text(text)
            .typography(Typography(size: 13, weight: .semibold))
            .foregroundStyle(theme.accentStrong)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(theme.accentTint, in: .capsule)
    }
}

private struct ActionRow: View {
    let title: String
    let icon: ImageResource
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(theme.accent.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .frame(width: 54, height: 54)
                    .overlay {
                        Image(icon)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(theme.accent)
                    }
                Text(title)
                    .typography(Typography(size: 17, weight: .semibold))
                    .foregroundStyle(theme.accentStrong)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, Spacing.s12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

struct HomeView: View {
    let user: AuthUser
    @Environment(\.theme) private var theme
    @Environment(InviteLinkRouter.self) private var inviteRouter
    @State private var trips: TripsStore
    @State private var plans: PlanStore
    @State private var expenses: ExpensesStore
    @State private var gallery: GalleryStore
    @State private var documents: DocumentsStore
    @State private var packing: PackingStore
    @State private var tasks: TasksStore
    @State private var polls: PollsStore
    @State private var isShowingAccount = false
    @State private var isCreatingTrip = false
    @State private var isShowingInspiration = false
    @State private var plannedDestination: TripDestination?
    @State private var isScanningInvite = false
    @State private var scannedInvite: String?
    @State private var openTrip: Trip?
    @State private var createdTrip: Trip?
    @State private var loadError: String?
    @State private var isShowingRefreshError = false

    init(user: AuthUser, auth: AuthStore) {
        self.user = user
        let tripsStore = TripsStore(auth: auth)
        _trips = State(initialValue: tripsStore)
        _plans = State(initialValue: PlanStore(api: tripsStore.api))
        _expenses = State(initialValue: ExpensesStore(api: tripsStore.api, trips: tripsStore))
        _gallery = State(initialValue: GalleryStore(api: tripsStore.api))
        _documents = State(initialValue: DocumentsStore(api: tripsStore.api))
        _packing = State(initialValue: PackingStore(api: tripsStore.api))
        _tasks = State(initialValue: TasksStore(api: tripsStore.api))
        _polls = State(initialValue: PollsStore(api: tripsStore.api))
    }

    var body: some View {
        NavigationStack {
            content
                .background { theme.background.ignoresSafeArea() }
                .navigationTitle("Wyjazdy")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu("Dodaj", image: .addRounded) {
                            Button("Nowy wyjazd", image: .addRounded) { isCreatingTrip = true }
                            Button("Dołącz przez kod QR", image: .qrCodeScanner) { isScanningInvite = true }
                            Button("Wylosuj cel podróży", image: .explore) { isShowingInspiration = true }
                        }
                    }
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { isShowingAccount = true } label: {
                            Text(String(user.name.prefix(1)).uppercased())
                                .typography(Typography(size: 17, weight: .bold))
                        }
                        .buttonStyle(.glassProminent)
                        .tint(theme.accent)
                        .accessibilityLabel("Konto")
                    }
                }
                .navigationDestination(isPresented: $isShowingAccount) {
                    ProfileView(user: user)
                }
                .navigationDestination(isPresented: $isShowingInspiration) {
                    InspirationView(user: user) { destination in
                        plannedDestination = destination
                        isCreatingTrip = true
                    }
                }
                .alert("Nie udało się odświeżyć", isPresented: $isShowingRefreshError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(loadError ?? "")
                }
        }
        .task { await load() }
        .sheet(isPresented: $isCreatingTrip, onDismiss: finishCreatingTrip) {
            TripFormView(user: user, destination: plannedDestination) { created in
                createdTrip = created
            }
        }
        .sheet(item: Bindable(inviteRouter).pending, onDismiss: openCreatedTrip) { invite in
            InviteJoinView(code: invite.code) { joined in
                createdTrip = joined
            }
        }
        .fullScreenCover(isPresented: $isScanningInvite, onDismiss: openScannedInvite) {
            InviteScannerView { slug in
                scannedInvite = slug
            }
        }
        .fullScreenCover(item: $openTrip) { trip in
            TripView(tripID: trip.id, user: user)
        }
        .environment(trips)
        .environment(plans)
        .environment(expenses)
        .environment(gallery)
        .environment(documents)
        .environment(packing)
        .environment(tasks)
        .environment(polls)
    }

    @ViewBuilder
    private var content: some View {
        if !trips.hasLoaded {
            if let loadError {
                ContentUnavailableView {
                    Label("Nie udało się wczytać wyjazdów", image: .flightTakeoff)
                } description: {
                    Text(loadError)
                } actions: {
                    Button("Spróbuj ponownie") {
                        Task { await load() }
                    }
                    .buttonStyle(.glassProminent)
                }
            } else {
                ProgressView()
            }
        } else {
            let today = LocalDate(.now)
            let sections = TripSections(trips: trips.trips, today: today)
            if sections.isEmpty {
                ContentUnavailableView {
                    Label("Nie masz jeszcze wyjazdów", image: .flightTakeoff)
                } description: {
                    Text("Zaplanuj pierwszy i zaproś ekipę.")
                } actions: {
                    Button("Utwórz wyjazd") { isCreatingTrip = true }
                        .buttonStyle(.glassProminent)
                    Button("Dołącz przez kod QR") { isScanningInvite = true }
                        .buttonStyle(.glass)
                }
            } else {
                list(sections, today: today)
            }
        }
    }

    private func list(_ sections: TripSections, today: LocalDate) -> some View {
        ScrollView {
            VStack(spacing: Spacing.s8) {
                if let featured = sections.featured {
                    SectionLabel(text: "NAJBLIŻSZY")
                    Button { openTrip = featured } label: {
                        FeaturedTripCard(trip: featured, viewerID: user.id, today: today)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, Spacing.s16)
                }

                SectionLabel(text: "ZAPLANOWANE")
                ListCard {
                    ForEach(sections.planned) { trip in
                        tripButton(trip, today: today)
                    }
                    ActionRow(title: "Nowy wyjazd", icon: .addRounded) { isCreatingTrip = true }
                    ActionRow(title: "Dołącz przez kod QR", icon: .qrCodeScanner) { isScanningInvite = true }
                    ActionRow(title: "Wylosuj cel podróży", icon: .explore) { isShowingInspiration = true }
                }

                if !sections.past.isEmpty {
                    SectionLabel(text: "MINIONE")
                        .padding(.top, Spacing.s16)
                    ListCard {
                        ForEach(sections.past) { trip in
                            tripButton(trip, today: today)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.bottom, Spacing.s24)
        }
        .refreshable { await refresh() }
    }

    private func tripButton(_ trip: Trip, today: LocalDate) -> some View {
        Button { openTrip = trip } label: {
            TripRow(trip: trip, today: today)
        }
        .buttonStyle(.plain)
    }

    private func finishCreatingTrip() {
        plannedDestination = nil
        if createdTrip != nil { isShowingInspiration = false }
        openCreatedTrip()
    }

    private func openCreatedTrip() {
        openTrip = createdTrip
        createdTrip = nil
    }

    /// Runs after the scanner is gone, since the invite sheet can't be presented on top of it.
    private func openScannedInvite() {
        guard let scannedInvite else { return }
        inviteRouter.open(code: scannedInvite)
        self.scannedInvite = nil
    }

    private func load() async {
        loadError = nil
        do throws(APIError) {
            try await trips.load()
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func refresh() async {
        do throws(APIError) {
            try await trips.load()
        } catch {
            loadError = error.localizedDescription
            isShowingRefreshError = true
        }
    }
}

#Preview {
    let auth = AuthStore()
    HomeView(
        user: AuthUser(
            id: "preview",
            name: "Kuba",
            email: "kuba@zmykamy.pl",
            image: nil,
            themePalette: "ocean",
            termsVersion: AuthStore.currentTermsVersion,
            termsAcceptedAt: .now
        ),
        auth: auth
    )
    .environment(auth)
    .environment(InviteLinkRouter())
}
