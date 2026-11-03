import SwiftUI

/// Horizontal strip of trip days; days that already have plan points show a dot.
struct PlanDayStrip: View {
    let days: [LocalDate]
    @Binding var selection: LocalDate
    let markedDays: Set<LocalDate>
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
                Circle()
                    .fill(markedDays.contains(day) ? secondary : .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(width: 50, height: 70)
            .background(isSelected ? theme.accent : .neutralWhite, in: .rect(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(PlanDateFormat.weekdayDayMonth(day, calendar: calendar))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
