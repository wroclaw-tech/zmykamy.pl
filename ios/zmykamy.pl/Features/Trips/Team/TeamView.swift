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
    @State private var emailInvites: [EmailInvite] = []
    @State private var resendingInviteID: EmailInvite.ID?
    @State private var inviteToCancel: EmailInvite?
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
                .padding(.bottom, trip.isOrganizer ? 0 : Spacing.s16)

                if trip.isOrganizer {
                    EmailInviteCard { (emails) throws(APIError) in
                        try await sendEmailInvites(to: emails)
                    }
                    .padding(.bottom, Spacing.s16)
                }

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

                if trip.isOrganizer && !emailInvites.isEmpty {
                    SectionLabel(text: "ZAPROSZENI · \(emailInvites.count)")
                        .padding(.top, Spacing.s16)
                    ListCard {
                        ForEach(emailInvites) { invite in
                            EmailInviteRow(invite: invite, isResending: resendingInviteID == invite.id) {
                                resend(invite)
                            }
                            .contextMenu {
                                Button("Anuluj zaproszenie", role: .destructive) { inviteToCancel = invite }
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
        .task(id: trip.id) { await loadEmailInvites() }
        .sheet(isPresented: $isShowingQR) {
            if let invite {
                InviteQRSheet(trip: trip, invite: invite)
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
        .confirmationDialog(
            "Anulować zaproszenie?",
            isPresented: Binding(get: { inviteToCancel != nil }, set: { if !$0 { inviteToCancel = nil } }),
            titleVisibility: .visible,
            presenting: inviteToCancel
        ) { invite in
            Button("Anuluj zaproszenie", role: .destructive) { cancel(invite) }
        } message: { invite in
            Text("Link z e-maila do \(invite.email) nadal będzie działać, dopóki nie wygenerujesz nowego.")
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

    private func loadEmailInvites() async {
        guard trip.isOrganizer else { return }
        do throws(APIError) {
            emailInvites = try await trips.emailInvites(for: trip)
        } catch {
            emailInvites = []
        }
    }

    private func sendEmailInvites(to emails: [String]) async throws(APIError) -> EmailInviteResult {
        let result = try await trips.sendEmailInvites(to: emails, for: trip)
        let sentIDs = Set(result.invites.map(\.id))
        emailInvites = result.invites + emailInvites.filter { !sentIDs.contains($0.id) }
        return result
    }

    private func resend(_ invite: EmailInvite) {
        resendingInviteID = invite.id
        perform { () throws(APIError) in
            defer { resendingInviteID = nil }
            let resent = try await trips.resend(invite, for: trip)
            emailInvites = [resent] + emailInvites.filter { $0.id != resent.id }
        }
    }

    private func cancel(_ invite: EmailInvite) {
        perform { () throws(APIError) in
            try await trips.cancel(invite, for: trip)
            emailInvites.removeAll { $0.id == invite.id }
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
