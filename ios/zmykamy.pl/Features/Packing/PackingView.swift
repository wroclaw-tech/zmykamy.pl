import SwiftUI

private extension PolishPlural {
    static func things(_ count: Int) -> String {
        "\(count) \(form(count, one: "rzecz", few: "rzeczy", many: "rzeczy"))"
    }

    static func remaining(_ count: Int) -> String {
        "\(form(count, one: "Została", few: "Zostały", many: "Zostało")) \(things(count))"
    }
}

private struct PackingSummary: View {
    let items: [PackingItem]
    let scope: PackingScope
    @Environment(\.theme) private var theme

    private var packedCount: Int {
        items.filter(\.isPacked).count
    }

    private var unassignedCount: Int {
        items.filter { $0.assigneeId == nil }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s12) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(packedCount) z \(items.count)")
                    .typography(.title2)
                    .foregroundStyle(.neutralInk)
                Spacer(minLength: Spacing.s8)
                if scope == .shared && unassignedCount > 0 {
                    Text("\(PolishPlural.things(unassignedCount)) bez opiekuna")
                        .typography(.subheadEmphasis)
                        .foregroundStyle(.statusDanger)
                } else if packedCount < items.count {
                    Text(PolishPlural.remaining(items.count - packedCount))
                        .typography(.subheadRegular)
                        .foregroundStyle(.neutralGray)
                } else {
                    Text("Wszystko spakowane")
                        .typography(.subheadRegular)
                        .foregroundStyle(.statusSuccess)
                }
            }
            ProgressBar(done: packedCount, total: items.count, track: theme.background)
            if scope == .shared {
                Text("Jedno na całą ekipę. Każda rzecz ma osobę, która ją bierze.")
                    .typography(.footnote)
                    .foregroundStyle(.neutralGray)
            }
        }
        .padding(Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.neutralWhite, in: .rect(cornerRadius: Radius.lg))
    }
}

private struct AssigneeChip: View {
    let item: PackingItem
    let trip: Trip
    let viewerID: String
    let onAssign: (String?) -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        if let assignee = trip.member(id: item.assigneeId) {
            Menu {
                assigneeOptions
            } label: {
                let isViewer = assignee.userId == viewerID
                HStack(spacing: Spacing.s6) {
                    MemberAvatar(member: assignee, viewerID: viewerID, size: 24, typography: Typography(size: 10, weight: .bold))
                    Text(isViewer ? "Ty" : assignee.name)
                        .typography(.subheadEmphasis)
                        .foregroundStyle(isViewer ? theme.accentStrong : .neutralInk)
                        .lineLimit(1)
                }
                .padding(.leading, 3)
                .padding(.trailing, Spacing.s12)
                .frame(height: 30)
                .background(isViewer ? theme.accentTint : theme.background, in: .capsule)
            }
            .accessibilityLabel("Kto bierze: \(assignee.name)")
        } else {
            Button { onAssign(viewerID) } label: {
                HStack(spacing: Spacing.s4) {
                    Image(.addRounded)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                    Text("Biorę")
                        .typography(.subheadEmphasis)
                }
                .foregroundStyle(theme.accentStrong)
                .padding(.leading, Spacing.s8)
                .padding(.trailing, Spacing.s12)
                .frame(height: 30)
                .overlay {
                    Capsule().strokeBorder(theme.accent, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
                .contentShape(.capsule)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var assigneeOptions: some View {
        ForEach(trip.members) { member in
            Button(member.userId == viewerID ? "Ty" : member.name) { onAssign(member.userId) }
        }
        Divider()
        Button("Nikt") { onAssign(nil) }
    }
}

private struct PackingRow: View {
    let item: PackingItem
    let trip: Trip
    let viewerID: String
    let onToggle: () -> Void
    let onAssign: (String?) -> Void

    private var status: (text: String, color: Color) {
        if item.isPacked {
            ("Spakowane", .neutralGray)
        } else if item.assigneeId == nil {
            ("Nikt jeszcze nie bierze", .statusDanger)
        } else {
            ("Jeszcze nie spakowane", .neutralGray)
        }
    }

    var body: some View {
        HStack(spacing: Spacing.s12) {
            CheckToggle(isOn: item.isPacked, action: onToggle)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .typography(.bodyRegular)
                    .foregroundStyle(item.isPacked ? .neutralGray2 : .neutralInk)
                if item.scope == .shared {
                    Text(status.text)
                        .typography(.footnote)
                        .foregroundStyle(status.color)
                }
            }
            Spacer(minLength: Spacing.s8)
            if item.scope == .shared {
                AssigneeChip(item: item, trip: trip, viewerID: viewerID, onAssign: onAssign)
            }
        }
        .padding(.leading, Spacing.s14)
        .padding(.trailing, Spacing.s14)
        .padding(.vertical, Spacing.s8)
        .frame(minHeight: item.scope == .shared ? 62 : 50)
        .contentShape(.rect)
    }
}

private struct AssigneeOverview: View {
    let trip: Trip
    let items: [PackingItem]
    let viewerID: String

    var body: some View {
        VStack(spacing: Spacing.s8) {
            HStack {
                SectionLabel(text: "KTO CO BIERZE")
                Text(PolishPlural.people(trip.members.count))
                    .typography(.footnote)
                    .foregroundStyle(.neutralGray)
                    .padding(.trailing, Spacing.s6)
            }
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.s16) {
                    ForEach(trip.members) { member in
                        VStack(spacing: Spacing.s6) {
                            MemberAvatar(member: member, viewerID: viewerID, size: 44, typography: Typography(size: 18, weight: .bold))
                                .overlay(alignment: .bottomTrailing) {
                                    Text("\(items.filter { $0.assigneeId == member.userId }.count)")
                                        .typography(.captionBadge)
                                        .foregroundStyle(.neutralInk)
                                        .frame(width: 20, height: 20)
                                        .background(.neutralWhite, in: .circle)
                                        .offset(x: 4, y: 4)
                                }
                            Text(member.userId == viewerID ? "Ty" : member.name)
                                .typography(.captionEmphasis)
                                .foregroundStyle(.neutralInk)
                                .lineLimit(1)
                        }
                        .frame(width: 50)
                    }
                }
                .padding(.horizontal, Spacing.s8)
                .padding(.vertical, Spacing.s4)
            }
            .scrollIndicators(.hidden)
        }
    }
}

struct PackingView: View {
    let trip: Trip
    let user: AuthUser

    @Environment(PackingStore.self) private var packing
    @Environment(\.theme) private var theme
    @State private var scope = PackingScope.personal
    @State private var isAdding = false
    @State private var newName = ""
    @State private var renamedItem: PackingItem?
    @State private var renamedName = ""
    @State private var loadError: String?
    @State private var errorMessage = ""
    @State private var isShowingError = false

    var body: some View {
        content
            .background { theme.background.ignoresSafeArea() }
            .navigationTitle("Pakowanie")
            .navigationSubtitle(trip.name)
            .task(id: trip.id) { await load() }
            .alert("Nowa rzecz", isPresented: $isAdding) {
                TextField("Nazwa", text: $newName)
                Button("Dodaj", action: add)
                Button("Anuluj", role: .cancel) { newName = "" }
            }
            .alert("Zmień nazwę", isPresented: Binding { renamedItem != nil } set: { if !$0 { renamedItem = nil } }) {
                TextField("Nazwa", text: $renamedName)
                Button("Zapisz", action: rename)
                Button("Anuluj", role: .cancel) {}
            }
            .alert("Coś poszło nie tak", isPresented: $isShowingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
    }

    @ViewBuilder
    private var content: some View {
        if let items = packing.items(for: trip, scope: scope) {
            ScrollView {
                VStack(spacing: Spacing.s20) {
                    Picker("Lista", selection: $scope) {
                        Text("Moje rzeczy").tag(PackingScope.personal)
                        Text("Wspólne").tag(PackingScope.shared)
                    }
                    .pickerStyle(.segmented)

                    if !items.isEmpty {
                        PackingSummary(items: items, scope: scope)
                    }
                    if scope == .shared {
                        AssigneeOverview(trip: trip, items: items, viewerID: user.id)
                    }
                    list(items)
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.bottom, Spacing.s24)
            }
            .refreshable { await refresh() }
        } else if let loadError {
            ContentUnavailableView {
                Label("Nie udało się wczytać listy", image: .luggage)
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

    private func list(_ items: [PackingItem]) -> some View {
        VStack(spacing: Spacing.s8) {
            if scope == .shared && !items.isEmpty {
                HStack {
                    SectionLabel(text: "LISTA WSPÓLNA")
                    Text(PolishPlural.things(items.count))
                        .typography(.footnote)
                        .foregroundStyle(.neutralGray)
                        .padding(.trailing, Spacing.s6)
                }
            }
            if items.isEmpty {
                Text(scope == .personal ? "Dodaj rzeczy, które chcesz zabrać." : "Dodaj rzeczy dla całej ekipy, np. głośnik albo apteczkę.")
                    .typography(.calloutRegular)
                    .foregroundStyle(.neutralGray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.s6)
            } else {
                ListCard {
                    ForEach(items) { item in
                        PackingRow(
                            item: item,
                            trip: trip,
                            viewerID: user.id,
                            onToggle: { update(item, PackingItemUpdate(isPacked: !item.isPacked)) },
                            onAssign: { update(item, PackingItemUpdate(assigneeId: .some($0))) }
                        )
                        .contextMenu {
                            Button("Zmień nazwę") {
                                renamedName = item.name
                                renamedItem = item
                            }
                            Button("Usuń", role: .destructive) {
                                run { try await packing.delete(item, from: trip) }
                            }
                        }
                    }
                }
            }
            DashedAddButton(title: "Dodaj rzecz") { isAdding = true }
                .padding(.top, Spacing.s4)
        }
    }

    private func add() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        newName = ""
        guard !name.isEmpty else { return }
        let request = PackingItemRequest(scope: scope, name: name)
        run { try await packing.add(request, to: trip) }
    }

    private func rename() {
        let name = renamedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let item = renamedItem, !name.isEmpty, name != item.name else { return }
        update(item, PackingItemUpdate(name: name))
    }

    private func update(_ item: PackingItem, _ update: PackingItemUpdate) {
        run { try await packing.update(item, with: update, in: trip) }
    }

    private func load() async {
        loadError = nil
        do throws(APIError) {
            try await packing.load(trip)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func refresh() async {
        do throws(APIError) {
            try await packing.load(trip)
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
    let item = { (id: String, scope: PackingScope, name: String, assignee: String?, isPacked: Bool) in
        PackingItem(id: id, scope: scope, name: name, assigneeId: assignee, isPacked: isPacked, createdBy: "kuba")
    }
    NavigationStack {
        PackingView(trip: .preview, user: .preview)
    }
    .environment(auth)
    .environment(PackingStore(api: AuthorizedAPI(auth: auth), items: [Trip.preview.id: [
        item("1", .personal, "Dowód osobisty", nil, true),
        item("2", .personal, "Karta EKUZ", nil, true),
        item("3", .personal, "Bluza na wieczór", nil, false),
        item("4", .personal, "Okulary przeciwsłoneczne", nil, true),
        item("5", .personal, "Słuchawki", nil, false),
        item("6", .shared, "Głośnik JBL", "bartek", true),
        item("7", .shared, "Krem z filtrem 50", "zuza", true),
        item("8", .shared, "Apteczka", "natalia", true),
        item("9", .shared, "Aparat na kliszę", "ola", false),
        item("10", .shared, "Przedłużacz", "kuba", false),
        item("11", .shared, "Parasol plażowy", nil, false),
    ]]))
}
