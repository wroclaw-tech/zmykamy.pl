import SwiftUI

struct TeamView: View {
    let trip: Trip
    let user: AuthUser
    @Environment(TripsStore.self) private var trips
    @Environment(\.theme) private var theme
    @State private var inviteState = InviteState.loading
    @State private var isShowingQR = false
    @State private var isConfirmingRegenerate = false
    @State private var isConfirmingLeave = false
    @State private var memberToRemove: TripMember?
    @State private var isWorking = false
    @State private var errorMessage = ""
    @State private var isShowingError = false

    private var invite: TripInvite? {
        if case .loaded(let invite) = inviteState { invite } else { nil }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.s8) {
                InviteCard(
                    tripName: trip.name,
                    state: inviteState,
                    canRegenerate: trip.isOrganizer,
                    onShowQR: { isShowingQR = true },
                    onRegenerate: { isConfirmingRegenerate = true },
                    onRetry: { Task { await loadInvite() } }
                )
                .padding(.bottom, Spacing.s16)

                membersHeader
                ListCard {
                    ForEach(trip.members) { member in
                        MemberRow(member: member, isViewer: member.userId == user.id, currency: trip.currency)
                            .contextMenu {
                                if trip.isOrganizer && member.userId != user.id {
                                    Button("Usuń z wyjazdu", role: .destructive) { memberToRemove = member }
                                }
                            }
                    }
                }

                if !trip.isOrganizer {
                    ListCard {
                        Button { isConfirmingLeave = true } label: {
                            Text("Opuść wyjazd")
                                .typography(.bodyEmphasis)
                                .foregroundStyle(.statusDanger)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.s14)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .disabled(isWorking)
                    }
                    .padding(.top, Spacing.s16)
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.bottom, Spacing.s24)
        }
        .background { theme.background.ignoresSafeArea() }
        .navigationTitle("Ekipa")
        .navigationSubtitle(trip.name)
        .toolbar {
            if let invite {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: invite.url, message: Text("Dołącz do wyjazdu „\(trip.name)” w Zmykamy")) {
                        Image(.personAdd)
                    }
                    .accessibilityLabel("Zaproś uczestników")
                }
            }
        }
        .task(id: trip.id) { await loadInvite() }
        .sheet(isPresented: $isShowingQR) {
            if let invite {
                InviteQRSheet(tripName: trip.name, invite: invite)
            }
        }
        .confirmationDialog("Wygenerować nowy link?", isPresented: $isConfirmingRegenerate, titleVisibility: .visible) {
            Button("Wygeneruj nowy link", role: .destructive, action: regenerateInvite)
        } message: {
            Text("Dotychczasowy link przestanie działać. Obecni uczestnicy zostają w wyjeździe.")
        }
        .confirmationDialog("Opuścić wyjazd?", isPresented: $isConfirmingLeave, titleVisibility: .visible) {
            Button("Opuść wyjazd", role: .destructive, action: leave)
        } message: {
            Text("Wrócisz do niego tylko z nowym zaproszeniem.")
        }
        .confirmationDialog(
            "Usunąć uczestnika?",
            isPresented: Binding(get: { memberToRemove != nil }, set: { if !$0 { memberToRemove = nil } }),
            titleVisibility: .visible,
            presenting: memberToRemove
        ) { member in
            Button("Usuń \(member.name)", role: .destructive) { remove(member) }
        } message: { member in
            Text("\(member.name) straci dostęp do wyjazdu.")
        }
        .alert("Coś poszło nie tak", isPresented: $isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var membersHeader: some View {
        HStack {
            Text("UCZESTNICY · \(trip.members.count)")
            Spacer()
            Text("Bilans")
        }
        .typography(.sectionLabel)
        .foregroundStyle(.neutralGray)
        .padding(.horizontal, Spacing.s6)
    }

    private func loadInvite() async {
        inviteState = .loading
        do throws(APIError) {
            inviteState = .loaded(try await trips.invite(for: trip))
        } catch {
            inviteState = .failed
        }
    }

    private func regenerateInvite() {
        perform { () throws(APIError) in
            inviteState = .loaded(try await trips.regenerateInvite(of: trip))
        }
    }

    private func remove(_ member: TripMember) {
        perform { () throws(APIError) in
            try await trips.remove(member, from: trip)
        }
    }

    private func leave() {
        perform { () throws(APIError) in
            try await trips.leave(trip)
        }
    }

    private func perform(_ action: @escaping () async throws(APIError) -> Void) {
        isWorking = true
        Task {
            do throws(APIError) {
                try await action()
            } catch {
                errorMessage = error.localizedDescription
                isShowingError = true
            }
            isWorking = false
        }
    }
}
