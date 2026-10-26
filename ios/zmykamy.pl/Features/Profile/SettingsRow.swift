import SwiftUI

struct SettingsRowLabel<RowDetails: View>: View {
    let icon: ImageResource
    let title: String
    var value: String?
    @ViewBuilder var rowDetails: RowDetails
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.s12) {
            IconBadge(image: icon, foreground: theme.accent, background: theme.accentTint)
            Text(title)
                .typography(.bodyRegular)
                .foregroundStyle(.neutralInk)
            Spacer(minLength: Spacing.s8)
            rowDetails
            if let value {
                Text(value)
                    .typography(.calloutRegular)
                    .foregroundStyle(.neutralGray)
            }
            Image(.chevronRight)
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundStyle(.neutralGray3)
        }
        .padding(.leading, Spacing.s14)
        .padding(.trailing, Spacing.s16)
        .padding(.vertical, Spacing.s12)
        .frame(minHeight: 58)
        .contentShape(.rect)
    }
}

extension SettingsRowLabel where RowDetails == EmptyView {
    init(icon: ImageResource, title: String, value: String? = nil) {
        self.init(icon: icon, title: title, value: value) { EmptyView() }
    }
}

struct SettingsRow<Destination: View, RowDetails: View>: View {
    let icon: ImageResource
    let title: String
    var value: String?
    @ViewBuilder var destination: Destination
    @ViewBuilder var rowDetails: RowDetails

    var body: some View {
        NavigationLink {
            destination
        } label: {
            SettingsRowLabel(icon: icon, title: title, value: value) { rowDetails }
        }
        .buttonStyle(.plain)
    }
}

extension SettingsRow where RowDetails == EmptyView {
    init(icon: ImageResource, title: String, value: String? = nil, @ViewBuilder destination: () -> Destination) {
        self.init(icon: icon, title: title, value: value, destination: destination) { EmptyView() }
    }
}
