import SwiftUI

struct FormCard<Trailing: View, Content: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s12) {
            HStack {
                Text(title)
                    .typography(.calloutEmphasis)
                    .foregroundStyle(.neutralInk)
                Spacer()
                trailing
            }
            content
        }
        .padding(Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.neutralWhite, in: .rect(cornerRadius: Radius.lg))
    }
}

extension FormCard where Trailing == EmptyView {
    init(title: String, @ViewBuilder content: () -> Content) {
        self.init(title: title, trailing: { EmptyView() }, content: content)
    }
}

struct FormFieldRow<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.s8) {
            content
        }
        .padding(.horizontal, Spacing.s14)
        .frame(minHeight: 44)
        .background(theme.background, in: .rect(cornerRadius: Radius.sm))
    }
}
