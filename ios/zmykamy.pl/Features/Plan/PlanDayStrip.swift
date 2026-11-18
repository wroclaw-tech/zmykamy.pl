import SwiftUI

/// Horizontal strip of trip days with the forecast when there is one; other days that
/// already have plan points show a dot.
struct PlanDayStrip: View {
    let days: [LocalDate]
    @Binding var selection: LocalDate
    let markedDays: Set<LocalDate>
    var weather: TripWeather?
    let calendar: Calendar
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s8) {
                    ForEach(days, id: \.self) { day in
                        cell(for: day)
                            .id(day)
                    }
                }
                .padding(.horizontal, Spacing.gutter)
            }
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
        }
    }

    private func cell(for day: LocalDate) -> some View {
        let isSelected = day == selection
        let primary: Color = isSelected ? .neutralWhite : .neutralInk
        let secondary: Color = isSelected ? .neutralWhite.opacity(0.85) : .neutralGray
        return Button { selection = day } label: {
            VStack(spacing: 2) {
                Text(PlanDateFormat.shortWeekday(day, calendar: calendar))
                    .typography(.captionEmphasis)
                    .foregroundStyle(secondary)
                Text("\(day.day)")
                    .typography(.title2)
                    .foregroundStyle(primary)
                if let forecast = weather?.forecast(on: day) {
                    HStack(spacing: 2) {
                        Image(forecast.condition.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                        Text(forecast.temperatureText)
                            .typography(.captionEmphasis)
                            .monospacedDigit()
                    }
                    .foregroundStyle(isSelected ? .neutralWhite : .neutralInk2)
                    .accessibilityHidden(true)
                } else {
                    Circle()
                        .fill(markedDays.contains(day) ? secondary : .clear)
                        .frame(width: 5, height: 5)
                        .frame(height: 14)
                }
            }
            .frame(width: 50, height: 77)
            .background(isSelected ? theme.accent : .neutralWhite, in: .rect(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: day))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func accessibilityLabel(for day: LocalDate) -> String {
        let date = PlanDateFormat.weekdayDayMonth(day, calendar: calendar)
        guard let forecast = weather?.forecast(on: day) else { return date }
        return "\(date), \(forecast.condition.label), \(forecast.temperatureText)"
    }
}
