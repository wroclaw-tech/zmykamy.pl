import MapKit
import SwiftUI

private struct ForecastColumn: Identifiable {
    let label: String
    let condition: WeatherCondition
    let temperature: String

    var id: String { label }
}

/// Blue weather tile on the trip overview: now and the next days during the trip, the forecast
/// once it reaches the trip, and the usual weather before that.
struct TripWeatherTile: View {
    let summary: TripWeatherSummary
    let calendar: Calendar

    private static let gradient = LinearGradient(
        colors: [Color(red: 0.353, green: 0.663, blue: 0.941), Color(red: 0.184, green: 0.498, blue: 0.847)],
        startPoint: UnitPoint(x: 0.33, y: 0),
        endPoint: UnitPoint(x: 0.67, y: 1)
    )
    private static let temperature = Typography(size: 44, weight: .light, tracking: -1.5)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.s4) {
                Image(.nearMe)
                    .resizable()
                    .frame(width: 16, height: 16)
                Text(place ?? "Pogoda")
                    .typography(.subheadEmphasis)
                    .lineLimit(1)
            }
            Text(headline)
                .typography(Self.temperature)
                .monospacedDigit()
                .padding(.top, Spacing.s4)
            details
            Spacer(minLength: 0)
        }
        .foregroundStyle(.neutralWhite)
        .padding(Spacing.s16)
        .frame(maxWidth: .infinity, minHeight: 183, alignment: .topLeading)
        .background(Self.gradient, in: .rect(cornerRadius: 28))
        .accessibilityElement(children: .combine)
    }

    private var place: String? {
        switch summary {
        case .now(let current, _, _): current.place
        case .forecast(let day, _): day.place
        case .typical(let typical, _, _): typical.place
        }
    }

    private var headline: String {
        switch summary {
        case .now(let current, _, _): current.temperatureText
        case .forecast(let day, _): day.temperatureText
        case .typical(let typical, _, _): "\(Int(typical.temperatureMax.rounded()))°"
        }
    }

    @ViewBuilder
    private var details: some View {
        switch summary {
        case .now(let current, let today, let next):
            Text(today.map(WeatherFormat.range) ?? current.condition.label)
                .typography(.subheadEmphasis)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            forecastRow([ForecastColumn(label: "Teraz", condition: current.condition, temperature: current.temperatureText)] + next.map(column))
                .padding(.top, Spacing.s4)
        case .forecast(let day, let next):
            Text(WeatherFormat.range(day))
                .typography(.subheadEmphasis)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            forecastRow(([day] + next).map(column))
                .padding(.top, Spacing.s4)
        case .typical(let typical, let tripStart, let leadDays):
            Text(WeatherFormat.usually(typical.condition, in: tripStart))
                .typography(.subheadEmphasis)
                .fixedSize(horizontal: false, vertical: true)
            Text(WeatherFormat.typicalDetails(typical, forecastLeadDays: leadDays))
                .typography(.captionRegular)
                .opacity(0.9)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.s6)
        }
    }

    private func column(_ day: DayWeather) -> ForecastColumn {
        ForecastColumn(
            label: PlanDateFormat.shortWeekday(day.date, calendar: calendar),
            condition: day.condition,
            temperature: day.temperatureText
        )
    }

    private func forecastRow(_ columns: [ForecastColumn]) -> some View {
        HStack(spacing: 0) {
            ForEach(columns) { column in
                VStack(spacing: Spacing.s4) {
                    Text(column.label)
                    Image(column.condition.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .accessibilityLabel(column.condition.label)
                    Text(column.temperature)
                        .monospacedDigit()
                }
                .typography(.captionEmphasis)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Map tile on the trip overview with directions to the next place from the plan.
struct TripPlaceTile: View {
    let point: PlanPoint
    let coordinate: PlanCoordinate
    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL

    private var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Map(initialPosition: .camera(MapCamera(centerCoordinate: location, distance: 1500)), interactionModes: []) {
                Annotation(point.place ?? point.title, coordinate: location, anchor: .bottom) {
                    Image(.locationOn)
                        .resizable()
                        .frame(width: 34, height: 34)
                        .foregroundStyle(theme.accent)
                }
                .annotationTitles(.hidden)
            }
            .frame(height: 95)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            HStack(alignment: .center, spacing: Spacing.s4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(point.place ?? point.title)
                        .typography(.subheadEmphasis)
                        .foregroundStyle(.neutralInk)
                        .lineLimit(2)
                    Text("Nawiguj")
                        .typography(.captionRegular)
                        .foregroundStyle(.neutralGray)
                }
                Spacer(minLength: 0)
                Menu {
                    ForEach(MapsApp.allCases) { app in
                        Button(app.title, image: app.icon) {
                            if let url = app.directionsURL(to: coordinate) {
                                openURL(url)
                            }
                        }
                    }
                } label: {
                    Image(.directions)
                        .resizable()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(.neutralWhite)
                        .frame(width: 32, height: 32)
                        .background(theme.accent, in: .circle)
                }
                .accessibilityLabel("Nawiguj do \(point.place ?? point.title)")
            }
            .padding(.horizontal, Spacing.s14)
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, minHeight: 183)
        .background(.neutralWhite, in: .rect(cornerRadius: 28))
        .clipShape(.rect(cornerRadius: 28))
    }
}

nonisolated extension TripPlan {
    /// The next plan point with a location at `now`, otherwise the first one in the plan.
    func nextLocatedPoint(at now: Date, calendar: Calendar) -> PlanPoint? {
        let located = points
            .filter { $0.coordinate != nil }
            .sorted { ($0.date, $0.time) < ($1.date, $1.time) }
        let today = LocalDate(now, calendar: calendar)
        let time = PlanTime(now, calendar: calendar)
        return located.first { ($0.date, $0.time) >= (today, time) } ?? located.first
    }
}
