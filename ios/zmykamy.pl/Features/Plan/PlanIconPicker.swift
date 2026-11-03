import SwiftUI

struct PlanIconPicker: View {
    @Binding var selection: PlanIcon
    @Environment(\.theme) private var theme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.s8), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.s8) {
            ForEach(PlanIcon.allCases, id: \.self) { icon in
                let isSelected = icon == selection
                let tint: Color = isSelected ? theme.accentStrong : .neutralInk2
                Button { selection = icon } label: {
                    Image(icon.resource)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(tint)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(isSelected ? theme.accentTint : theme.background, in: .rect(cornerRadius: Radius.sm))
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .strokeBorder(theme.accent, lineWidth: isSelected ? 1.5 : 0)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(icon.label)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}
