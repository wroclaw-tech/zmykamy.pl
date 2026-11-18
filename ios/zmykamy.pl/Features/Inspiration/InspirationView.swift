import SwiftUI

private struct FilterChip: View {
    let icon: ImageResource
    let title: String
    let isActive: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.s6) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(isActive ? AnyShapeStyle(.neutralWhite) : AnyShapeStyle(theme.accent))
            Text(title)
                .typography(.subheadEmphasis)
                .foregroundStyle(isActive ? AnyShapeStyle(.neutralWhite) : AnyShapeStyle(.neutralInk))
        }
        .padding(.leading, 10)
        .padding(.trailing, Spacing.s14)
        .padding(.vertical, Spacing.s8)
        .background(isActive ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.neutralWhite), in: .capsule)
        .contentShape(.capsule)
    }
}

struct InspirationView: View {
    let onPlan: (TripDestination) -> Void
    @Environment(\.theme) private var theme
    @State private var filters: InspirationFilters
    @State private var selected: InspirationDestination?
    @State private var rotation = GlobeRotation.initial
    @State private var dragStart: GlobeRotation?

    private let currentMonth = Calendar.current.component(.month, from: .now)

    init(user: AuthUser, onPlan: @escaping (TripDestination) -> Void) {
        self.onPlan = onPlan
        _filters = State(initialValue: InspirationFilters(climate: user.themePalette.flatMap(VacationClimate.init(rawValue:))))
    }

    private var pool: [InspirationDestination] {
        filters.apply(to: InspirationDestination.catalog, currentMonth: currentMonth)
    }

    private var month: Int {
        filters.month ?? currentMonth
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.s16) {
                filterChips
                globe
                destinationCard
                    .padding(.horizontal, Spacing.gutter)
            }
            .padding(.bottom, Spacing.s24)
        }
        .background { theme.background.ignoresSafeArea() }
        .navigationTitle("Inspiracje")
        .navigationSubtitle("Zakręć globusem i wylosuj, dokąd zmykacie.")
        .onAppear {
            if selected == nil { draw() }
        }
        .onChange(of: filters) {
            if selected.map({ !filters.matches($0, currentMonth: currentMonth) }) ?? true { draw() }
        }
        .sensoryFeedback(.selection, trigger: selected)
    }

    private var filterChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.s8) {
                Menu {
                    Picker("Klimat", selection: $filters.climate) {
                        Text("Dowolny klimat").tag(VacationClimate?.none)
                        ForEach(VacationClimate.allCases) { climate in
                            Text(climate.title).tag(Optional(climate))
                        }
                    }
                } label: {
                    FilterChip(icon: .locationOn, title: filters.climate?.title ?? "Klimat", isActive: filters.climate != nil)
                }
                Menu {
                    Picker("Czas lotu", selection: $filters.maxFlightHours) {
                        Text("Dowolny czas lotu").tag(Int?.none)
                        ForEach(InspirationFilters.flightHourOptions, id: \.self) { hours in
                            Text(InspirationFormat.maxFlight(hours: hours)).tag(Optional(hours))
                        }
                    }
                } label: {
                    FilterChip(icon: .flight, title: filters.maxFlightHours.map { InspirationFormat.maxFlight(hours: $0) } ?? "Czas lotu", isActive: filters.maxFlightHours != nil)
                }
                Menu {
                    Picker("Miesiąc", selection: $filters.month) {
                        Text("Dowolny miesiąc").tag(Int?.none)
                        ForEach(1...12, id: \.self) { month in
                            Text(InspirationFormat.month(month)).tag(Optional(month))
                        }
                    }
                } label: {
                    FilterChip(icon: .calendarToday, title: filters.month.map(InspirationFormat.month) ?? "Miesiąc", isActive: filters.month != nil)
                }
                Button {
                    filters.warmOnly.toggle()
                } label: {
                    FilterChip(icon: .sunny, title: "Ciepło", isActive: filters.warmOnly)
                }
                .accessibilityAddTraits(filters.warmOnly ? .isSelected : [])
            }
            .buttonStyle(.plain)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, Spacing.gutter, for: .scrollContent)
    }

    private var globe: some View {
        VStack(spacing: Spacing.s8) {
            InspirationGlobe(rotation: rotation, destinations: pool, selected: selected)
                .contentShape(.rect)
                .gesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { value in
                            let start = dragStart ?? rotation
                            dragStart = start
                            rotation = start.dragged(by: value.translation)
                        }
                        .onEnded { _ in dragStart = nil }
                )
                .onTapGesture(perform: draw)
                .accessibilityElement()
                .accessibilityLabel("Globus")
                .accessibilityValue(selected?.name ?? "")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(named: "Losuj", draw)
            HStack(spacing: Spacing.s6) {
                Image(.explore)
                Text("Przeciągnij, żeby obrócić · stuknij, żeby wylosować")
                    .typography(.footnote)
            }
            .foregroundStyle(.neutralGray)
            .padding(.horizontal, Spacing.gutter)
        }
    }

    private var destinationCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s14) {
            if let selected {
                HStack(spacing: Spacing.s12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selected.name)
                            .typography(.title2)
                            .foregroundStyle(.neutralInk)
                        Text("\(selected.country) · \(InspirationFormat.flightTime(selected.flightMinutes))")
                            .typography(.subheadRegular)
                            .foregroundStyle(.neutralGray)
                    }
                    Spacer(minLength: 0)
                    weather(selected)
                }
                FlowLayout(spacing: Spacing.s6, lineSpacing: Spacing.s6) {
                    ForEach(selected.tags, id: \.self) { tag in
                        Text(tag)
                            .typography(.subheadRegular)
                            .foregroundStyle(.neutralInk)
                            .padding(.horizontal, Spacing.s14)
                            .padding(.vertical, Spacing.s8)
                            .background(theme.background, in: .capsule)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nic tu nie pasuje")
                        .typography(.title2)
                        .foregroundStyle(.neutralInk)
                    Text("Poluzuj filtry, żeby było z czego losować.")
                        .typography(.subheadRegular)
                        .foregroundStyle(.neutralGray)
                }
            }
            actions
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.neutralWhite, in: .rect(cornerRadius: Radius.xl))
        .animation(.smooth, value: selected)
    }

    private func weather(_ destination: InspirationDestination) -> some View {
        let isWarm = destination.high(in: month) >= InspirationFilters.warmHigh
        return HStack(spacing: Spacing.s6) {
            Image(isWarm ? .sunny : .thermostat)
                .foregroundStyle(isWarm ? AnyShapeStyle(.statusWarning) : AnyShapeStyle(.statusInfo))
            Text(InspirationFormat.weather(destination, in: month))
                .typography(.subheadEmphasis)
                .foregroundStyle(.neutralInk)
        }
        .padding(.leading, 10)
        .padding(.trailing, Spacing.s12)
        .padding(.vertical, Spacing.s6)
        .background(isWarm ? AnyShapeStyle(.statusWarningTint) : AnyShapeStyle(.statusInfoTint), in: .capsule)
        .fixedSize()
    }

    private var actions: some View {
        HStack(spacing: 10) {
            if let selected {
                secondaryButton("Losuj", icon: .shuffle, action: draw)
                Button { onPlan(selected.tripDestination) } label: {
                    HStack(spacing: Spacing.s8) {
                        Image(.flightTakeoff)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        Text("Zaplanuj wyjazd")
                            .typography(.headline)
                    }
                    .foregroundStyle(.neutralWhite)
                    .padding(.horizontal, Spacing.s20)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(theme.accent, in: .capsule)
                }
            } else {
                secondaryButton("Wyczyść filtry", icon: .refresh, action: clearFilters)
            }
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String, icon: ImageResource, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.s8) {
                Image(icon)
                    .foregroundStyle(theme.accent)
                Text(title)
                    .typography(.headline)
                    .foregroundStyle(.neutralInk)
            }
            .padding(.horizontal, Spacing.s20)
            .frame(height: 50)
            .frame(maxWidth: selected == nil ? .infinity : nil)
            .background(theme.background, in: .capsule)
        }
    }

    private func draw() {
        selected = pool.draw(excluding: selected)
        if let selected {
            withAnimation(.smooth(duration: 1.4)) {
                rotation = rotation.centering(selected)
            }
        }
    }

    private func clearFilters() {
        filters = InspirationFilters()
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        InspirationView(user: .preview) { _ in }
    }
}
#endif
