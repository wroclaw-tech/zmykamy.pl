import SwiftUI

private struct StatView: View {
    let number: Int
    let label: String

    var body: some View {
        VStack(spacing: 1) {
            Text("\(number)")
                .typography(.title2)
                .foregroundStyle(.neutralInk)
            Text(label)
                .typography(.footnote)
                .foregroundStyle(.neutralGray)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StatDivider: View {
    var body: some View {
        Rectangle()
            .fill(.alphaSeparator)
            .frame(width: 1, height: 34)
    }
}

private struct AvatarView: View {
    let user: AuthUser
    @Environment(\.theme) private var theme

    var body: some View {
        Circle()
            .fill(theme.accent)
            .frame(width: 96, height: 96)
            .overlay {
                Text(user.name.prefix(1))
                    .typography(.displayCountdown)
                    .foregroundStyle(.neutralWhite)
            }
    }
}

struct ProfileView: View {
    let user: AuthUser
    @Environment(AuthStore.self) private var auth
    @Environment(\.theme) private var theme

    private var currentClimate: VacationClimate {
        VacationClimate(rawValue: user.themePalette ?? "") ?? .ocean
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.s24) {
                VStack(spacing: Spacing.s4) {
                    AvatarView(user: user)
                        .padding(.bottom, Spacing.s12)
                    Text(user.name)
                        .typography(.title1)
                        .foregroundStyle(.neutralInk)
                    Text(user.email)
                        .typography(.subheadRegular)
                        .foregroundStyle(.neutralGray)
                }

                HStack(spacing: 0) {
                    StatView(number: 0, label: "todo")
                    StatDivider()
                    StatView(number: 0, label: "todo")
                    StatDivider()
                    StatView(number: 0, label: "todo")
                }
                .padding(.horizontal, Spacing.s8)
                .padding(.vertical, Spacing.s16)
                .background(.neutralWhite, in: .rect(cornerRadius: Radius.xl))

                Button {
                } label: {
                    HStack(spacing: Spacing.s12) {
                        IconBadge(image: .payments, foreground: .neutralWhite, background: theme.accent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Do oddania: todo")
                                .typography(.bodyEmphasis)
                                .foregroundStyle(.neutralInk)
                            Text("todo")
                                .typography(.footnote)
                                .foregroundStyle(.neutralInk2)
                        }
                        Spacer(minLength: Spacing.s8)
                        Image(.chevronRight)
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundStyle(theme.accent)
                    }
                    .padding(.horizontal, Spacing.s14)
                    .padding(.vertical, Spacing.s12)
                    .background(theme.accentTint, in: .rect(cornerRadius: Radius.lg))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)

                VStack(spacing: Spacing.s8) {
                    SectionLabel(text: "KONTO")
                    ListCard(separatorInset: 62) {
                        SettingsRow(icon: .person, title: "Dane osobowe") {
                            PersonalDetailsView(user: user)
                        }
                        SettingsRow(icon: .lock, title: "Logowanie i bezpieczeństwo") {
                            SecurityView(user: user)
                        }
                        SettingsRow(icon: .accountBalance, title: "Dane do przelewów") {
                            PaymentDetailsView(user: user)
                        }
                    }
                }

                VStack(spacing: Spacing.s8) {
                    SectionLabel(text: "APLIKACJA")
                    ListCard(separatorInset: 62) {
                        SettingsRow(icon: .palette, title: "Kolorystyka", value: theme.name) {
                            ThemeSettingsView(current: currentClimate)
                        } rowDetails: {
                            ThemePreview(theme: theme, size: 16)
                        }
                        SettingsRow(icon: .notifications, title: "Powiadomienia") {
                            EmptyView()
                        }
                        SettingsRow(icon: .settings, title: "Ustawienia aplikacji") {
                            AppSettingsView(user: user)
                        }
                    }
                }

                Button {
                    Task { await auth.signOut() }
                } label: {
                    HStack(spacing: Spacing.s8) {
                        Image(.logout)
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text("Wyloguj się")
                            .typography(.bodyEmphasis)
                    }
                    .foregroundStyle(.statusDanger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.s16)
                    .background(.neutralWhite, in: .rect(cornerRadius: Radius.xl))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.bottom, 48)
        }
        .background { theme.background.ignoresSafeArea() }
    }
}

#Preview {
    NavigationStack {
        ProfileView(user: AuthUser(
            id: "preview",
            name: "Kuba",
            email: "kuba@zmykamy.pl",
            image: nil,
            themePalette: "ocean",
            termsVersion: AuthStore.currentTermsVersion,
            termsAcceptedAt: .now
        ))
    }
    .environment(AuthStore())
}
