import SwiftUI

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .typography(.sectionLabel)
            .foregroundStyle(.neutralGray)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.s6)
    }
}
