import SwiftUI

/// One plan point on the day timeline: time, marker on the line, and a card. While the group
/// is travelling to the point, the card stands out and offers navigation apps.
struct PlanTimelineRow: View {
    let point: PlanPoint
    let isLast: Bool
    let showsMarker: Bool
    let isEditable: Bool
    var isTravelling = false
    /// When navigation becomes relevant, if that is still ahead.
    var navigationStart: PlanTime?
    var documents: [TripDocument] = []
    var onOpenDocument: (TripDocument) -> Void = { _ in }
    let onTap: () -> Void
    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL

    private var showsNavigationMenu: Bool {
        point.coordinate != nil && !isTravelling
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s8) {
            Text(point.time.text)
                .typography(.calloutEmphasis)
                .monospacedDigit()
                .foregroundStyle(.neutralInk2)
                .frame(width: 46, alignment: .leading)
                .padding(.top, Spacing.s14)
            marker
            VStack(alignment: .leading, spacing: Spacing.s6) {
                card
                if !documents.isEmpty || showsNavigationMenu {
                    attachments
                }
            }
            .padding(.bottom, isLast ? 0 : Spacing.s12)
        }
    }

    private static let dotTopInset: CGFloat = 15

    private var marker: some View {
        ZStack(alignment: .top) {
            if showsMarker {
                if !isLast {
                    Rectangle()
                        .fill(theme.accent.opacity(0.25))
                        .frame(width: 2)
                        .padding(.top, Self.dotTopInset + 11)
                        .padding(.bottom, -Self.dotTopInset)
                }
                Circle()
                    .fill(theme.accentTint)
                    .frame(width: 16, height: 16)
                    .overlay {
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 10, height: 10)
                    }
                    .padding(.top, Self.dotTopInset)
            }
        }
        .frame(width: 16)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var attachments: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.s6) {
                if showsNavigationMenu, let coordinate = point.coordinate {
                    navigationMenu(to: coordinate)
                }
                ForEach(documents) { document in
                    Button { onOpenDocument(document) } label: {
                        HStack(spacing: Spacing.s4) {
                            Image(.attachFile)
                                .resizable()
                                .frame(width: 14, height: 14)
                            Text(document.title)
                                .typography(.captionEmphasis)
                                .lineLimit(1)
                        }
                        .foregroundStyle(theme.accentStrong)
                        .padding(.horizontal, Spacing.s12)
                        .frame(height: 30)
                        .background(theme.accentTint, in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func navigationMenu(to coordinate: PlanCoordinate) -> some View {
        Menu {
            ForEach(MapsApp.allCases) { app in
                Button(app.title, image: app.icon) { open(app, to: coordinate) }
            }
        } label: {
            HStack(spacing: Spacing.s4) {
                Image(.directions)
                    .resizable()
                    .frame(width: 14, height: 14)
                Text(navigationStart.map { "Nawigacja od \($0.text)" } ?? "Nawigacja")
                    .typography(.captionEmphasis)
                    .lineLimit(1)
            }
            .foregroundStyle(.neutralGray)
            .padding(.horizontal, Spacing.s12)
            .frame(height: 30)
            .background(.neutralWhite, in: .capsule)
        }
        .buttonStyle(.plain)
    }

    private func open(_ app: MapsApp, to coordinate: PlanCoordinate) {
        guard let url = app.directionsURL(to: coordinate) else { return }
        openURL(url)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Spacing.s12) {
            Button(action: onTap) {
                header
            }
            .buttonStyle(.plain)
            .disabled(!isEditable)
            if isTravelling, let coordinate = point.coordinate {
                navigationButtons(to: coordinate)
            }
        }
        .padding(Spacing.s14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.neutralWhite, in: .rect(cornerRadius: Radius.md))
        .overlay {
            if isTravelling {
                RoundedRectangle(cornerRadius: Radius.md)
                    .strokeBorder(theme.accent, lineWidth: 2)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.s12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(point.title)
                    .typography(.bodyEmphasis)
                    .foregroundStyle(.neutralInk)
                    .multilineTextAlignment(.leading)
                if let subtitle = point.subtitle {
                    Text(subtitle)
                        .typography(.subheadRegular)
                        .foregroundStyle(.neutralGray)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: Spacing.s8)
            if isTravelling {
                Text("W DRODZE")
                    .typography(.captionBadge)
                    .foregroundStyle(.neutralWhite)
                    .padding(.horizontal, Spacing.s8)
                    .padding(.vertical, Spacing.s4)
                    .background(theme.accent, in: .rect(cornerRadius: Radius.xs / 2))
            } else {
                Image(point.icon.resource)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(theme.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }

    private func navigationButtons(to coordinate: PlanCoordinate) -> some View {
        HStack(spacing: Spacing.s8) {
            ForEach(MapsApp.allCases) { app in
                Button { open(app, to: coordinate) } label: {
                    VStack(spacing: Spacing.s4) {
                        Image(app.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundStyle(theme.accentStrong)
                        Text(app.title)
                            .typography(.captionEmphasis)
                            .foregroundStyle(.neutralInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(theme.background, in: .rect(cornerRadius: Radius.sm))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Nawiguj w \(app.title)")
            }
        }
    }
}
