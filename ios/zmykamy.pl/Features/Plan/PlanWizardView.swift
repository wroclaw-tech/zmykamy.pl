import SwiftUI

private struct WizardPointRow: View {
    let point: PlanPoint
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.s12) {
            Text(point.time.text)
                .typography(.calloutEmphasis)
                .monospacedDigit()
                .foregroundStyle(.neutralInk)
                .frame(width: 44, alignment: .leading)
            IconBadge(image: point.icon.resource, foreground: theme.accentStrong, background: theme.accentTint)
            VStack(alignment: .leading, spacing: 2) {
                Text(point.title)
                    .typography(.bodyEmphasis)
                    .foregroundStyle(.neutralInk)
                if let subtitle = point.subtitle {
                    Text(subtitle)
                        .typography(.subheadRegular)
                        .foregroundStyle(.neutralGray)
                        .lineLimit(2)
                }
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.s14)
        .padding(.vertical, Spacing.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}

/// Step of the new trip flow where the first plan points are added. Every step can be skipped.
struct PlanWizardView: View {
    static let stepCount = 2

    let trip: Trip
    let user: AuthUser
    let onFinish: () -> Void

    @Environment(PlanStore.self) private var plans
    @Environment(\.theme) private var theme
    @State private var pointSheet: PointSheet?
    @State private var showsAllDays = false

    private struct PointSheet: Identifiable {
        let id = UUID()
        var point: PlanPoint?
        var date: LocalDate
    }

    private var calendar: Calendar {
        user.calendar
    }

    private var plan: TripPlan {
        plans.plan(for: trip) ?? .empty
    }

    private var days: [LocalDate] {
        trip.days(calendar: calendar)
    }

    private var visibleDays: [LocalDate] {
        if showsAllDays { return days }
        let lastPlanned = days.lastIndex { !plan.points(on: $0).isEmpty } ?? -1
        return Array(days.prefix(max(2, lastPlanned + 1)))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s20) {
                header
                progress
                ForEach(Array(visibleDays.enumerated()), id: \.element) { index, day in
                    daySection(day, number: index + 1)
                }
                collapsedDays
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.s12)
            .padding(.bottom, Spacing.s24)
        }
        .background { theme.background.ignoresSafeArea() }
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close, action: onFinish)
            }
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(
                title: plan.points.isEmpty ? "Pomiń na razie" : "Gotowe",
                icon: plan.points.isEmpty ? nil : .check,
                action: onFinish
            )
            .padding(.horizontal, Spacing.gutter)
            .padding(.bottom, Spacing.s8)
        }
        .sheet(item: $pointSheet) { sheet in
            PlanPointFormView(trip: trip, user: user, point: sheet.point, date: sheet.date)
        }
        .task { try? await plans.load(trip) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            Text("Nowy wyjazd · krok 2 z \(Self.stepCount)")
                .typography(.calloutRegular)
                .foregroundStyle(.neutralGray)
            Text("Plan wyjazdu")
                .typography(.titleLarge)
                .foregroundStyle(.neutralInk)
            Text("Rozpisz dni teraz albo uzupełnij plan później.")
                .typography(.calloutRegular)
                .foregroundStyle(.neutralInk2)
                .padding(.top, Spacing.s4)
        }
        .padding(.horizontal, Spacing.s4)
    }

    private var progress: some View {
        HStack(spacing: Spacing.s6) {
            ForEach(0..<Self.stepCount, id: \.self) { _ in
                Capsule()
                    .fill(theme.accent)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, Spacing.s4)
        .accessibilityHidden(true)
    }

    private func daySection(_ day: LocalDate, number: Int) -> some View {
        VStack(spacing: Spacing.s8) {
            SectionLabel(text: PlanDateFormat.wizardHeading(day: number, date: day, calendar: calendar))
            ListCard(separatorInset: 70) {
                ForEach(plan.points(on: day)) { point in
                    Button { pointSheet = PointSheet(point: point, date: day) } label: {
                        WizardPointRow(point: point)
                    }
                    .buttonStyle(.plain)
                    .disabled(!trip.canEdit(authoredBy: point.author, userID: user.id))
                }
                Button { pointSheet = PointSheet(date: day) } label: {
                    HStack(spacing: Spacing.s6) {
                        Image(.addRounded)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                        Text("Dodaj punkt")
                            .typography(.bodyEmphasis)
                    }
                    .foregroundStyle(theme.accentStrong)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var collapsedDays: some View {
        let hidden = days.count - visibleDays.count
        if hidden > 0 {
            VStack(spacing: Spacing.s8) {
                SectionLabel(text: collapsedHeading(hidden: hidden))
                Button { showsAllDays = true } label: {
                    HStack(spacing: Spacing.s12) {
                        Text("\(PolishPlural.days(hidden)) bez planu. Zostawcie je puste albo uzupełnijcie plan później.")
                            .typography(.calloutRegular)
                            .foregroundStyle(.neutralInk2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(.chevronRight)
                            .foregroundStyle(.neutralGray)
                    }
                    .padding(Spacing.s16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.neutralWhite, in: .rect(cornerRadius: Radius.xl))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func collapsedHeading(hidden: Int) -> String {
        let first = visibleDays.count + 1
        return hidden == 1 ? "DZIEŃ \(first)" : "DNI \(first)–\(days.count)"
    }
}
