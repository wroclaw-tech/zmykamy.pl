import SwiftUI

private struct PollOptionRow: View {
    let option: PollOption
    let poll: Poll
    let trip: Trip
    let viewerID: String
    let action: () -> Void
    @Environment(\.theme) private var theme

    private var isMine: Bool {
        poll.myOptionId == option.id
    }

    private var fraction: CGFloat {
        poll.voterCount == 0 ? 0 : CGFloat(option.voteCount) / CGFloat(poll.voterCount)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Group {
                    if isMine {
                        Image(.checkCircle)
                            .resizable()
                            .foregroundStyle(theme.accent)
                    } else {
                        Image(.radioButtonUnchecked)
                            .resizable()
                            .foregroundStyle(.neutralGray3)
                    }
                }
                .scaledToFit()
                .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.name)
                        .typography(.bodyEmphasis)
                        .foregroundStyle(.neutralInk)
                    if let description = option.description {
                        Text(description)
                            .typography(.footnote)
                            .foregroundStyle(.neutralGray)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: Spacing.s8)
                MemberAvatarStack(
                    members: trip.members.filter { option.voterIds.contains($0.userId) },
                    viewerID: viewerID,
                    size: 22,
                    borderColor: theme.background
                )
                Text("\(option.voteCount)")
                    .typography(Typography(size: 16, weight: .bold))
                    .foregroundStyle(.neutralInk)
                    .frame(minWidth: 16, alignment: .trailing)
            }
            .padding(.horizontal, Spacing.s14)
            .padding(.vertical, Spacing.s12)
            .frame(minHeight: 59)
            .background(alignment: .leading) {
                GeometryReader { proxy in
                    theme.accent.opacity(0.12)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .background(theme.background)
            .clipShape(.rect(cornerRadius: 18))
            .contentShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(poll.status != .open)
        .accessibilityValue("\(option.voteCount) głosów")
        .accessibilityAddTraits(isMine ? .isSelected : [])
    }
}

private struct OpenPollCard: View {
    let poll: Poll
    let trip: Trip
    let user: AuthUser
    let onVote: (PollOption) -> Void
    let onResolve: () -> Void
    let onDelete: () -> Void
    @Environment(\.theme) private var theme

    private var meta: String {
        let author = trip.member(id: poll.createdBy)
        var parts: [String] = []
        if poll.createdBy == user.id {
            parts.append("Ty pytasz")
        } else if let author {
            parts.append("\(author.name) pyta")
        }
        if let closesAt = poll.closesAt, poll.status == .open {
            let calendar = user.calendar
            let time = PlanTime(closesAt, calendar: calendar).text
            let day = calendar.isDateInToday(closesAt)
                ? "dziś"
                : TripDateFormat.dayMonth(LocalDate(closesAt, calendar: calendar), calendar: calendar)
            parts.append("Do \(day), \(time)")
        }
        return parts.joined(separator: " · ")
    }

    private var footer: String {
        let voted = PolishPlural.form(poll.voterCount, one: "Zagłosowała", few: "Zagłosowały", many: "Zagłosowało")
        let base = "\(voted) \(poll.voterCount) z \(PolishPlural.people(trip.members.count))."
        return poll.status == .open && poll.myOptionId == nil ? "\(base) Brakuje Twojego głosu." : base
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            HStack(spacing: Spacing.s8) {
                if poll.status == .open {
                    StatusPill(title: "Otwarte", foreground: theme.accentStrong, background: theme.accentTint)
                } else {
                    StatusPill(title: "Zakończone", foreground: .statusWarning, background: .statusWarningTint)
                }
                Text(meta)
                    .typography(Typography(size: 13, weight: .semibold))
                    .foregroundStyle(.neutralGray)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if trip.canManage(poll, userID: user.id) {
                    Menu {
                        Button("Rozstrzygnij", action: onResolve)
                        Button("Usuń", role: .destructive, action: onDelete)
                    } label: {
                        Image(.moreHoriz)
                            .foregroundStyle(.neutralGray)
                            .frame(width: 28, height: 24)
                    }
                    .accessibilityLabel("Więcej")
                }
            }
            Text(poll.question)
                .typography(.title3)
                .foregroundStyle(.neutralInk)
                .padding(.top, Spacing.s4)
                .padding(.bottom, Spacing.s4)
            ForEach(poll.options) { option in
                PollOptionRow(option: option, poll: poll, trip: trip, viewerID: user.id) {
                    onVote(option)
                }
            }
            Text(footer)
                .typography(.subheadRegular)
                .foregroundStyle(.neutralGray)
                .padding(.top, Spacing.s4)
            if poll.status == .closed && trip.canManage(poll, userID: user.id) {
                Button("Rozstrzygnij", action: onResolve)
                    .typography(.bodyEmphasis)
                    .foregroundStyle(theme.accentStrong)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.neutralWhite, in: .rect(cornerRadius: Radius.xxl))
    }
}

private struct StatusPill<Foreground: ShapeStyle, Background: ShapeStyle>: View {
    let title: String
    let foreground: Foreground
    let background: Background

    var body: some View {
        Text(title)
            .typography(Typography(size: 13, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(background, in: .capsule)
    }
}

private struct ResolvedPollCard: View {
    let poll: Poll
    let calendar: Calendar

    private var score: String {
        poll.options.map(\.voteCount).sorted(by: >).map(String.init).joined(separator: " : ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s12) {
            Text(poll.question)
                .typography(.bodyEmphasis)
                .foregroundStyle(.neutralInk)
            if let winner = poll.winningOption {
                HStack(spacing: 10) {
                    Image(.emojiEvents)
                        .foregroundStyle(.statusSuccess)
                    Text(winner.name)
                        .typography(.calloutRegular)
                        .foregroundStyle(.neutralInk)
                    Spacer(minLength: Spacing.s8)
                    Text(score)
                        .typography(Typography(size: 15, weight: .bold))
                        .foregroundStyle(.neutralInk)
                }
            }
            if let planDate = poll.planDate {
                Text("Dzień w planie: \(PlanDateFormat.weekdayDayMonth(planDate, calendar: calendar))")
                    .typography(.footnote)
                    .foregroundStyle(.neutralGray)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.neutralWhite, in: .rect(cornerRadius: Radius.xl))
    }
}

struct PollsView: View {
    let trip: Trip
    let user: AuthUser

    @Environment(PollsStore.self) private var polls
    @Environment(\.theme) private var theme
    @State private var isCreating = false
    @State private var resolvedPoll: Poll?
    @State private var deletedPoll: Poll?
    @State private var loadError: String?
    @State private var errorMessage = ""
    @State private var isShowingError = false

    var body: some View {
        content
            .background { theme.background.ignoresSafeArea() }
            .navigationTitle("Głosowania")
            .navigationSubtitle(trip.name)
            .task(id: trip.id) { await load() }
            .sheet(isPresented: $isCreating) {
                PollFormView(trip: trip, user: user)
            }
            .sheet(item: $resolvedPoll) { poll in
                PollResolveView(trip: trip, user: user, poll: poll)
            }
            .confirmationDialog(
                "Usunąć głosowanie?",
                isPresented: Binding { deletedPoll != nil } set: { if !$0 { deletedPoll = nil } },
                titleVisibility: .visible,
                presenting: deletedPoll
            ) { poll in
                Button("Usuń głosowanie", role: .destructive) {
                    run { try await polls.delete(poll, from: trip) }
                }
            } message: { _ in
                Text("Głosowanie i oddane głosy znikną dla wszystkich uczestników.")
            }
            .alert("Coś poszło nie tak", isPresented: $isShowingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
    }

    @ViewBuilder
    private var content: some View {
        if let list = polls.polls(for: trip) {
            let active = list.filter { $0.status != .resolved }
            let resolved = list.filter { $0.status == .resolved }
            ScrollView {
                VStack(spacing: Spacing.s12) {
                    if list.isEmpty {
                        ContentUnavailableView {
                            Label("Brak głosowań", image: .howToVote)
                        } description: {
                            Text("Zapytaj ekipę, gdzie idziecie na kolację albo którą plażę wybrać.")
                        }
                    }
                    ForEach(active) { poll in
                        OpenPollCard(
                            poll: poll,
                            trip: trip,
                            user: user,
                            onVote: { vote(for: $0, in: poll) },
                            onResolve: { resolvedPoll = poll },
                            onDelete: { deletedPoll = poll }
                        )
                    }
                    if !resolved.isEmpty {
                        SectionLabel(text: "ROZSTRZYGNIĘTE")
                            .padding(.top, Spacing.s12)
                        ForEach(resolved) { poll in
                            ResolvedPollCard(poll: poll, calendar: user.calendar)
                                .contextMenu {
                                    if trip.canManage(poll, userID: user.id) {
                                        Button("Usuń", role: .destructive) { deletedPoll = poll }
                                    }
                                }
                        }
                    }
                    Button { isCreating = true } label: {
                        HStack(spacing: Spacing.s6) {
                            Image(.addRounded)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("Nowe głosowanie")
                                .typography(.bodyEmphasis)
                        }
                        .foregroundStyle(.neutralWhite)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.neutralInk, in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.bottom, Spacing.s24)
            }
            .refreshable { await refresh() }
        } else if let loadError {
            ContentUnavailableView {
                Label("Nie udało się wczytać głosowań", image: .howToVote)
            } description: {
                Text(loadError)
            } actions: {
                Button("Spróbuj ponownie") { Task { await load() } }
                    .buttonStyle(.glassProminent)
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func vote(for option: PollOption, in poll: Poll) {
        if poll.myOptionId == option.id {
            run { try await polls.withdrawVote(in: poll, of: trip) }
        } else {
            run { try await polls.vote(for: option, in: poll, of: trip) }
        }
    }

    private func load() async {
        loadError = nil
        do throws(APIError) {
            try await polls.load(trip)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func refresh() async {
        do throws(APIError) {
            try await polls.load(trip)
        } catch {
            errorMessage = error.localizedDescription
            isShowingError = true
        }
    }

    private func run(_ operation: @escaping () async throws -> Void) {
        Task {
            do {
                try await operation()
            } catch {
                errorMessage = error.localizedDescription
                isShowingError = true
            }
        }
    }
}

#Preview {
    let auth = AuthStore()
    let today = LocalDate(.now)
    NavigationStack {
        PollsView(trip: .preview, user: .preview)
    }
    .environment(auth)
    .environment(PollsStore(api: AuthorizedAPI(auth: auth), polls: [Trip.preview.id: [
        Poll(
            id: "1",
            question: "Kolacja w piątek: gdzie idziemy?",
            status: .open,
            createdBy: "zuza",
            closesAt: Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: .now),
            winningOptionId: nil,
            planDate: nil,
            myOptionId: nil,
            voterCount: 5,
            options: [
                PollOption(id: "a", name: "Cervejaria Ramiro", description: "Owoce morza, ale kolejka", voteCount: 3, voterIds: ["zuza", "bartek", "michał"]),
                PollOption(id: "b", name: "Time Out Market", description: "Każdy bierze, co chce", voteCount: 2, voterIds: ["ola", "natalia"]),
                PollOption(id: "c", name: "Gotujemy w domu", description: "Tanio i bez kolejki", voteCount: 0, voterIds: []),
            ]
        ),
        Poll(
            id: "2",
            question: "Plaża w sobotę: Carcavelos czy Costa da Caparica?",
            status: .resolved,
            createdBy: "kuba",
            closesAt: nil,
            winningOptionId: "d",
            planDate: today.adding(days: 15),
            myOptionId: "d",
            voterCount: 6,
            options: [
                PollOption(id: "d", name: "Carcavelos", description: nil, voteCount: 4, voterIds: ["kuba", "zuza", "ola", "bartek"]),
                PollOption(id: "e", name: "Costa da Caparica", description: nil, voteCount: 2, voterIds: ["michał", "natalia"]),
            ]
        ),
    ]]))
}
