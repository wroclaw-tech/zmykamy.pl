import QuickLook
import SwiftUI

private enum PlanMode: String, CaseIterable, Identifiable {
    case days = "Dzień po dniu"
    case info = "Ogólne"

    var id: String { rawValue }
}

private struct PointSheet: Identifiable {
    let id = UUID()
    var point: PlanPoint?
    var date: LocalDate
}

private struct InfoSheet: Identifiable {
    let id = UUID()
    var card: TripInfoCard?
}

/// The trip's plan tab: a day-by-day timeline and general info cards.
struct PlanView: View {
    let trip: Trip
    let user: AuthUser

    @Environment(PlanStore.self) private var plans
    @Environment(DocumentsStore.self) private var documents
    @State private var opener = DocumentOpener()
    @Environment(\.theme) private var theme
    @State private var mode = PlanMode.days
    @State private var selectedDay: LocalDate
    @State private var pointSheet: PointSheet?
    @State private var infoSheet: InfoSheet?
    @State private var loadError: String?
    @State private var isShowingRefreshError = false

    init(trip: Trip, user: AuthUser) {
        self.trip = trip
        self.user = user
        let today = LocalDate(.now, calendar: user.calendar)
        _selectedDay = State(initialValue: trip.startDate <= today && today <= trip.endDate ? today : trip.startDate)
    }

    private var calendar: Calendar {
        user.calendar
    }

    var body: some View {
        NavigationStack {
            content
                .background { theme.background.ignoresSafeArea() }
                .navigationTitle("Plan")
                .navigationSubtitle(trip.name)
                .toolbar {
                    CloseTripButton()
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Dodaj", image: .addRounded, action: add)
                    }
                }
                .sheet(item: $pointSheet) { sheet in
                    PlanPointFormView(trip: trip, user: user, point: sheet.point, date: sheet.date)
                }
                .sheet(item: $infoSheet) { sheet in
                    TripInfoFormView(trip: trip, card: sheet.card)
                }
                .alert("Nie udało się odświeżyć", isPresented: $isShowingRefreshError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(loadError ?? "")
                }
        }
        .task(id: trip.id) {
            await load()
            await documents.loadIfNeeded(trip)
        }
        .task(id: weatherInputs) { await plans.loadWeather(trip) }
        .quickLookPreview($opener.previewURL)
    }

    /// What the forecast depends on, so it reloads when a located point changes.
    private var weatherInputs: [String] {
        let located = plans.plan(for: trip)?.points.compactMap { point in
            point.coordinate.map { "\(point.date.rawValue)-\(point.time.text)-\($0.latitude),\($0.longitude)" }
        } ?? []
        return [trip.id, trip.startDate.rawValue, trip.endDate.rawValue] + located
    }

    private func open(_ document: TripDocument) {
        Task {
            do throws(APIError) {
                try await opener.open(document, using: documents)
            } catch {
                loadError = "Nie udało się otworzyć dokumentu. Sprawdź połączenie i spróbuj ponownie."
                isShowingRefreshError = true
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let plan = plans.plan(for: trip) {
            ScrollView {
                VStack(spacing: Spacing.s16) {
                    Picker("Widok", selection: $mode) {
                        ForEach(PlanMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Spacing.gutter)

                    switch mode {
                    case .days: daysContent(plan)
                    case .info: infoContent(plan)
                    }
                }
                .padding(.bottom, Spacing.s24)
            }
            .refreshable { await refresh() }
        } else if let loadError {
            ContentUnavailableView {
                Label("Nie udało się wczytać planu", image: .calendarMonth)
            } description: {
                Text(loadError)
            } actions: {
                Button("Spróbuj ponownie") { Task { await load() } }
                    .buttonStyle(.glassProminent)
            }
        } else {
            ProgressView()
        }
    }

    private func daysContent(_ plan: TripPlan) -> some View {
        let days = trip.days(calendar: calendar)
        let points = plan.points(on: selectedDay)
        let dayNumber = (days.firstIndex(of: selectedDay) ?? 0) + 1
        let isToday = selectedDay == LocalDate(.now, calendar: calendar)
        let weather = plans.weather(for: trip)
        let timeline = PlanDayTimeline(day: selectedDay, points: points)
        return VStack(alignment: .leading, spacing: Spacing.s16) {
            PlanDayStrip(
                days: days,
                selection: $selectedDay,
                markedDays: Set(plan.points.map(\.date)),
                weather: weather,
                calendar: calendar
            )
            HStack(alignment: .center, spacing: Spacing.s12) {
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    Text("Dzień \(dayNumber) · \(PlanDateFormat.weekdayDayMonth(selectedDay, calendar: calendar))")
                        .typography(.title2)
                        .foregroundStyle(.neutralInk)
                    if isToday {
                        Text("dziś")
                            .typography(.calloutRegular)
                            .foregroundStyle(.neutralGray)
                    }
                }
                Spacer(minLength: 0)
                if let forecast = weather?.forecast(on: selectedDay) {
                    WeatherPill(forecast: forecast)
                }
            }
            .padding(.horizontal, Spacing.s20)

            TimelineView(.everyMinute) { context in
                timelineContent(timeline, now: context.date)
            }
            .padding(.horizontal, Spacing.gutter)
        }
    }

    private func timelineContent(_ timeline: PlanDayTimeline, now: Date) -> some View {
        let points = timeline.points
        let travellingID = timeline.travellingPointID(at: now, calendar: calendar)
        return VStack(spacing: 0) {
            ForEach(points) { point in
                PlanTimelineRow(
                    point: point,
                    isLast: point.id == points.last?.id,
                    showsMarker: points.count > 1,
                    isEditable: trip.canEdit(authoredBy: point.author, userID: user.id),
                    isTravelling: point.id == travellingID,
                    navigationStart: timeline.navigationIsAhead(for: point, at: now, calendar: calendar)
                        ? timeline.navigationStart(for: point)
                        : nil,
                    documents: documents.documents(attachedTo: point, in: trip),
                    onOpenDocument: open,
                    onTap: { pointSheet = PointSheet(point: point, date: point.date) }
                )
            }
            if points.isEmpty {
                Text("Nic jeszcze nie zaplanowano na ten dzień.")
                    .typography(.calloutRegular)
                    .foregroundStyle(.neutralGray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, Spacing.s16)
            }
            DashedAddButton(title: "Dodaj punkt") {
                pointSheet = PointSheet(date: selectedDay)
            }
            .padding(.top, points.isEmpty ? 0 : Spacing.s12)
        }
    }

    private func infoContent(_ plan: TripPlan) -> some View {
        VStack(spacing: Spacing.s12) {
            ForEach(plan.info) { card in
                let isEditable = trip.canEdit(authoredBy: card.author, userID: user.id)
                Button { infoSheet = InfoSheet(card: card) } label: {
                    InfoCardView(card: card)
                }
                .buttonStyle(.plain)
                .disabled(!isEditable)
            }
            if plan.info.isEmpty {
                ContentUnavailableView {
                    Label("Brak informacji", image: .info)
                } description: {
                    Text("Dodaj nocleg, dojazd albo coś, co przyda się całej ekipie.")
                }
            }
            DashedAddButton(title: "Dodaj informację") {
                infoSheet = InfoSheet()
            }
        }
        .padding(.horizontal, Spacing.gutter)
    }

    private func add() {
        switch mode {
        case .days: pointSheet = PointSheet(date: selectedDay)
        case .info: infoSheet = InfoSheet()
        }
    }

    private func load() async {
        loadError = nil
        do throws(APIError) {
            try await plans.load(trip)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func refresh() async {
        do throws(APIError) {
            try await plans.load(trip)
        } catch {
            loadError = error.localizedDescription
            isShowingRefreshError = true
        }
    }
}

/// "☀ 21° · Sintra" next to the day heading.
private struct WeatherPill: View {
    let forecast: DayWeather

    var body: some View {
        HStack(spacing: Spacing.s6) {
            Image(forecast.condition.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
            Text([forecast.temperatureText, forecast.place].compactMap(\.self).joined(separator: " · "))
                .typography(.subheadEmphasis)
                .lineLimit(1)
        }
        .foregroundStyle(.statusWarning)
        .padding(.horizontal, Spacing.s12)
        .frame(height: 34)
        .background(.statusWarningTint, in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pogoda: \(forecast.condition.label), \(forecast.temperatureText)\(forecast.place.map { ", \($0)" } ?? "")")
    }
}

private struct InfoCardView: View {
    let card: TripInfoCard
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s12) {
            IconBadge(image: card.icon.resource, foreground: theme.accentStrong, background: theme.accentTint)
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text(card.title)
                    .typography(.bodyEmphasis)
                    .foregroundStyle(.neutralInk)
                if !card.text.isEmpty {
                    Text(card.text)
                        .typography(.subheadRegular)
                        .foregroundStyle(.neutralInk2)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.neutralWhite, in: .rect(cornerRadius: Radius.lg))
        .contentShape(.rect(cornerRadius: Radius.lg))
    }
}
