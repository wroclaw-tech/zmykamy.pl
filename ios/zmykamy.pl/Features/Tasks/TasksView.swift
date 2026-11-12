import SwiftUI

private struct TaskSheet: Identifiable {
    let id = UUID()
    var task: TripTask?
}

private struct TasksSummary: View {
    let trip: Trip
    let doneCount: Int
    let totalCount: Int
    let today: LocalDate
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s14) {
            HStack(spacing: Spacing.s12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(doneCount) z \(totalCount)")
                        .typography(.title1)
                        .foregroundStyle(.neutralInk)
                    Text("zadań zrobionych przed wyjazdem")
                        .typography(.subheadRegular)
                        .foregroundStyle(.neutralGray)
                }
                Spacer(minLength: 0)
                if case .upcoming(let daysLeft) = trip.phase(on: today) {
                    HStack(spacing: 5) {
                        Image(.hourglassTop)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                        Text("za \(PolishPlural.days(daysLeft))")
                            .typography(.subheadEmphasis)
                    }
                    .foregroundStyle(theme.accentStrong)
                    .padding(.leading, 10)
                    .padding(.trailing, Spacing.s12)
                    .padding(.vertical, Spacing.s6)
                    .background(theme.accentTint, in: .capsule)
                }
            }
            ProgressBar(done: doneCount, total: totalCount, track: .alphaFill)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.neutralWhite, in: .rect(cornerRadius: Radius.xl))
    }
}

private struct TaskRow: View {
    let task: TripTask
    let trip: Trip
    let viewerID: String
    let today: LocalDate
    let calendar: Calendar
    let onToggle: () -> Void
    let onEdit: () -> Void

    private var assignee: TripMember? {
        trip.member(id: task.assigneeId)
    }

    private var isOverdue: Bool {
        !task.isDone && task.dueDate.map { $0 < today } == true
    }

    private var subtitle: String? {
        var parts: [String] = []
        if let assignee {
            parts.append(assignee.userId == viewerID ? "Ty" : assignee.name)
        }
        if task.isDone, let completedAt = task.completedAt {
            parts.append(TripDateFormat.dayMonth(LocalDate(completedAt, calendar: calendar), calendar: calendar))
        } else if let dueDate = task.dueDate {
            parts.append(dueText(dueDate))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func dueText(_ date: LocalDate) -> String {
        switch today.days(until: date, calendar: calendar) {
        case 0: "na dziś"
        case -1: "termin minął wczoraj"
        case ..<0: "termin minął \(TripDateFormat.dayMonth(date, calendar: calendar))"
        default: "do \(TripDateFormat.dayMonth(date, calendar: calendar))"
        }
    }

    var body: some View {
        HStack(spacing: Spacing.s12) {
            CheckToggle(isOn: task.isDone, size: 24, action: onToggle)
            Button(action: onEdit) {
                HStack(spacing: Spacing.s12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title)
                            .typography(.bodyRegular)
                            .foregroundStyle(task.isDone ? .neutralGray : .neutralInk)
                            .strikethrough(task.isDone)
                            .multilineTextAlignment(.leading)
                        if let subtitle {
                            Text(subtitle)
                                .typography(.footnote)
                                .foregroundStyle(isOverdue ? .statusWarning : .neutralGray)
                        }
                    }
                    .opacity(task.isDone ? 0.8 : 1)
                    Spacer(minLength: 0)
                    if let assignee {
                        MemberAvatar(member: assignee, viewerID: viewerID)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, Spacing.s14)
        .padding(.trailing, Spacing.s16)
        .padding(.vertical, 11)
    }
}

struct TasksView: View {
    let trip: Trip
    let user: AuthUser

    @Environment(TasksStore.self) private var tasks
    @Environment(TripsStore.self) private var trips
    @Environment(\.theme) private var theme
    @State private var sheet: TaskSheet?
    @State private var loadError: String?
    @State private var errorMessage = ""
    @State private var isShowingError = false

    private var calendar: Calendar {
        user.calendar
    }

    var body: some View {
        content
            .background { theme.background.ignoresSafeArea() }
            .navigationTitle("Do zrobienia")
            .navigationSubtitle(trip.name)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Dodaj", image: .addRounded) { sheet = TaskSheet() }
                }
            }
            .sheet(item: $sheet) { sheet in
                TaskFormView(trip: trip, user: user, task: sheet.task)
            }
            .task(id: trip.id) { await load() }
            .alert("Coś poszło nie tak", isPresented: $isShowingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
    }

    @ViewBuilder
    private var content: some View {
        if let list = tasks.tasks(for: trip) {
            let today = LocalDate(.now, calendar: calendar)
            let open = list.filter { !$0.isDone }
            let done = list.filter(\.isDone)
            ScrollView {
                VStack(spacing: 22) {
                    TasksSummary(trip: trip, doneCount: done.count, totalCount: list.count, today: today)
                    if list.isEmpty {
                        ContentUnavailableView {
                            Label("Brak zadań", image: .checkCircle)
                        } description: {
                            Text("Dodaj rzeczy do załatwienia przed wyjazdem, np. bilety albo ubezpieczenie.")
                        }
                    }
                    section("DO ZROBIENIA · \(open.count)", open, today: today)
                    section("ZROBIONE · \(done.count)", done, today: today)
                    related
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.bottom, 48)
            }
            .refreshable { await refresh() }
        } else if let loadError {
            ContentUnavailableView {
                Label("Nie udało się wczytać zadań", image: .checkCircle)
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

    @ViewBuilder
    private func section(_ title: String, _ list: [TripTask], today: LocalDate) -> some View {
        if !list.isEmpty {
            VStack(spacing: Spacing.s8) {
                SectionLabel(text: title)
                ListCard(separatorInset: 50) {
                    ForEach(list) { task in
                        TaskRow(
                            task: task,
                            trip: trip,
                            viewerID: user.id,
                            today: today,
                            calendar: calendar,
                            onToggle: { toggle(task) },
                            onEdit: { sheet = TaskSheet(task: task) }
                        )
                    }
                }
            }
        }
    }

    private var related: some View {
        VStack(spacing: Spacing.s8) {
            SectionLabel(text: "POWIĄZANE")
            ListCard {
                NavigationLink {
                    PackingView(trip: trip, user: user)
                } label: {
                    HStack(spacing: Spacing.s12) {
                        IconBadge(image: .luggage, foreground: theme.accent, background: theme.accentTint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pakowanie")
                                .typography(.bodyRegular)
                                .foregroundStyle(.neutralInk)
                            if let count = trips.progress[trip.id]?.packing.mine {
                                Text("\(count.packedCount) z \(count.totalCount) rzeczy spakowanych")
                                    .typography(.footnote)
                                    .foregroundStyle(.neutralGray)
                            }
                        }
                        Spacer(minLength: Spacing.s8)
                        Image(.chevronRight)
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundStyle(.neutralGray3)
                    }
                    .padding(.leading, Spacing.s14)
                    .padding(.trailing, Spacing.s16)
                    .padding(.vertical, 11)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggle(_ task: TripTask) {
        Task {
            do throws(APIError) {
                try await tasks.update(task, with: TripTaskUpdate(isDone: !task.isDone), in: trip)
            } catch {
                errorMessage = error.localizedDescription
                isShowingError = true
            }
        }
    }

    private func load() async {
        loadError = nil
        do throws(APIError) {
            try await tasks.load(trip)
        } catch {
            loadError = error.localizedDescription
        }
        try? await trips.loadProgress(of: trip)
    }

    private func refresh() async {
        do throws(APIError) {
            try await tasks.load(trip)
        } catch {
            errorMessage = error.localizedDescription
            isShowingError = true
        }
    }
}

#if DEBUG
#Preview {
    let auth = AuthStore()
    let today = LocalDate(.now)
    let task = { (id: String, title: String, assignee: String?, due: Int?, completedDaysAgo: Int?) in
        TripTask(
            id: id,
            title: title,
            assigneeId: assignee,
            dueDate: due.map { today.adding(days: $0) },
            isDone: completedDaysAgo != nil,
            completedAt: completedDaysAgo.map { Date.now.addingTimeInterval(-Double($0) * 24 * 3600) },
            createdBy: "kuba"
        )
    }
    NavigationStack {
        TasksView(trip: .preview, user: .preview)
    }
    .environment(auth)
    .environment(TripsStore(auth: auth))
    .environment(TasksStore(api: AuthorizedAPI(auth: auth), tasks: [Trip.preview.id: [
        task("1", "Kupić bilety na pociąg do Sintry", "kuba", 5, nil),
        task("2", "Odprawa online na lot TP 1253", "michał", 11, nil),
        task("3", "Zarezerwować stolik na fado", "zuza", -1, nil),
        task("4", "Wymienić trochę euro na start", nil, nil, nil),
        task("5", "Kupić bilety lotnicze", "michał", nil, 40),
        task("6", "Wykupić ubezpieczenie podróżne", "natalia", nil, 3),
    ]]))
    .environment(PackingStore(api: AuthorizedAPI(auth: auth)))
}
#endif
