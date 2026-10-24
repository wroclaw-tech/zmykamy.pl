import SwiftUI

private struct ClimateTile: View {
    let climate: VacationClimate
    let isSelected: Bool
    let isDimmed: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24)
        Color.clear
            .frame(height: 144)
            .overlay {
                Image(climate.image)
                    .resizable()
                    .scaledToFill()
            }
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 90)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(climate.title)
                        .typography(Typography(size: 17, weight: .bold, tracking: -0.2))
                    Text(climate.subtitle)
                        .typography(.footnote)
                }
                .foregroundStyle(.neutralWhite)
                .lineLimit(1)
                .padding(Spacing.s12)
            }
            .overlay(alignment: .topTrailing) {
                selectionIndicator
                    .padding(isSelected ? 10 : Spacing.s12)
            }
            .clipShape(shape)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 27).fill(.neutralWhite).padding(-3)
                }
            }
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 30).fill(theme.accent).padding(-6)
                }
            }
            .shadow(
                color: .black.opacity(isSelected ? 0.18 : 0.08),
                radius: isSelected ? 12 : 1.5,
                y: isSelected ? 10 : 1
            )
            .opacity(isDimmed ? 0.55 : 1)
    }

    @ViewBuilder
    private var selectionIndicator: some View {
        if isSelected {
            Image(.checkCircle)
                .resizable()
                .frame(width: 30, height: 30)
                .foregroundStyle(theme.accent)
                .background(.neutralWhite, in: .circle)
                .shadow(color: .black.opacity(0.2), radius: 2, y: 2)
        } else {
            Circle()
                .fill(.neutralWhite.opacity(0.18))
                .background(.ultraThinMaterial, in: .circle)
                .overlay { Circle().strokeBorder(.neutralWhite.opacity(0.9), lineWidth: 2) }
                .frame(width: 26, height: 26)
        }
    }
}

struct ClimateGrid: View {
    @Binding var selection: VacationClimate?

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(VacationClimate.allCases) { climate in
                Button {
                    withAnimation(.snappy) { selection = climate }
                } label: {
                    ClimateTile(
                        climate: climate,
                        isSelected: selection == climate,
                        isDimmed: selection != nil && selection != climate
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(climate.title), \(climate.subtitle)")
                .accessibilityAddTraits(selection == climate ? .isSelected : [])
            }
        }
    }
}
