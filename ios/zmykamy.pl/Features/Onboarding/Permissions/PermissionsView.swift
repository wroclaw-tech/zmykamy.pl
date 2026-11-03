import SwiftUI

private struct PermissionButton: View {
    let status: PermissionStatus
    let onRequest: () -> Void
    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL

    var body: some View {
        switch status {
        case .granted:
            HStack(spacing: Spacing.s6) {
                Image(.checkCircle)
                    .resizable()
                    .frame(width: 20, height: 20)
                Text("Włączone")
            }
            .typography(.bodyEmphasis)
            .foregroundStyle(.statusSuccess)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(.statusSuccessTint, in: .capsule)
            .accessibilityElement(children: .combine)
        case .notDetermined:
            requestButton(title: "Pozwól", action: onRequest)
        case .denied:
            requestButton(title: "Otwórz Ustawienia") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
        }
    }

    private func requestButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.s6) {
                Image(.arrowForward)
                    .resizable()
                    .frame(width: 20, height: 20)
                Text(title)
            }
            .typography(.bodyEmphasis)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .tint(theme.accent)
    }
}

private struct PermissionCard<Preview: View>: View {
    let icon: ImageResource
    let title: String
    let description: String
    let status: PermissionStatus
    let onRequest: () -> Void
    @ViewBuilder let preview: Preview
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(icon)
                    .resizable()
                    .frame(width: 27, height: 33)
                    .foregroundStyle(theme.accentStrong)
                    .frame(width: 50, height: 50)
                    .background(theme.accentTint, in: .rect(cornerRadius: 16))

                VStack(alignment: .leading, spacing: Spacing.s4) {
                    Text(title)
                        .typography(Typography(size: 18, weight: .bold, tracking: -0.2))
                        .foregroundStyle(.neutralInk)
                    Text(description)
                        .typography(.calloutRegular)
                        .foregroundStyle(.neutralInk2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            preview

            PermissionButton(status: status, onRequest: onRequest)
        }
        .padding(Spacing.s16)
        .background(.neutralWhite, in: .rect(cornerRadius: 28))
    }
}

private struct NotificationPreview: View {
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AppMark(size: 38)

            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text("zmykamy")
                        .typography(Typography(size: 13, weight: .bold))
                        .foregroundStyle(.neutralInk)
                    Spacer()
                    Text("teraz")
                        .typography(.footnote)
                        .foregroundStyle(.neutralGray)
                }
                Text("Zuza dodała wydatek")
                    .typography(.subheadEmphasis)
                    .foregroundStyle(.neutralInk)
                Text("Kolacja w Time Out Market, 684 zł. Twoja część: 114 zł.")
                    .typography(.subheadRegular)
                    .foregroundStyle(.neutralInk2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.s12)
        .background(theme.background, in: .rect(cornerRadius: Radius.lg))
        .accessibilityHidden(true)
    }
}

struct PermissionsView: View {
    let onFinish: () -> Void
    @State private var permissions = PermissionsModel()
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.s12) {
                OnboardingStepHeader(
                    step: 3,
                    stepCount: 3,
                    title: "Uprawnienia",
                    subtitle: "Aplikacja potrzebuje dwóch zgód. Możesz je zmienić w dowolnym momencie w Ustawieniach.",
                    onSkip: onFinish
                )
                .padding(.bottom, Spacing.s8)

                PermissionCard(
                    icon: .photoCamera,
                    title: "Aparat i zdjęcia",
                    description: "Umożliwia dodawanie zdjęć i filmów do wspólnej galerii wyjazdu.",
                    status: permissions.camera,
                    onRequest: { Task { await permissions.requestCamera() } },
                    preview: { EmptyView() }
                )

                PermissionCard(
                    icon: .notifications,
                    title: "Powiadomienia",
                    description: "Informacje o nowych wydatkach, głosowaniach i zbliżającym się wylocie.",
                    status: permissions.notifications,
                    onRequest: { Task { await permissions.requestNotifications() } },
                    preview: { NotificationPreview() }
                )
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.s12)
            .padding(.bottom, Spacing.s16)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            Button(action: onFinish) {
                HStack(spacing: Spacing.s6) {
                    Text("Gotowe")
                    Image(.flightTakeoff)
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                .typography(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
            .tint(.neutralInk)
            .padding(.horizontal, Spacing.gutter)
        }
        .background { theme.background.ignoresSafeArea() }
        .task { await permissions.refresh() }
    }
}

#Preview {
    PermissionsView(onFinish: {})
}
