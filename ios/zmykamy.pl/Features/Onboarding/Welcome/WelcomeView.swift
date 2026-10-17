import SwiftUI

private struct PhotoCard: View {
    let image: String
    let size: CGSize

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24)
        Image(image)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipShape(shape)
            .overlay { shape.strokeBorder(.neutralWhite, lineWidth: 4) }
            .shadow(color: .black.opacity(0.16), radius: 14, y: 12)
    }
}

private enum BadgeIcon {
    case symbol(String)
    case avatar(String, Color)
}
private struct ShowcaseBadge: View {
    let text: String
    let icon: BadgeIcon
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.s6) {
            switch icon {
            case .symbol(let name):
                Image(name)
                    .resizable()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(theme.accent)
                    .padding(.leading, Spacing.s4)
            case .avatar(let initial, let color):
                Text(initial)
                    .typography(.captionBadge)
                    .foregroundStyle(.neutralWhite)
                    .frame(width: 26, height: 26)
                    .background(color, in: Circle())
                    .padding(.trailing, 1)
            }
            Text(text)
                .typography(.subheadEmphasis)
                .foregroundStyle(.neutralInk)
        }
        .padding(.leading, Spacing.s6)
        .padding(.trailing, Spacing.s12)
        .frame(height: 36)
        .background(.thinMaterial, in: Capsule())
    }
}

private struct PhotoCollage: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            PhotoCard(image: "onboarding_lisbon", size: CGSize(width: 128, height: 164))
                .rotationEffect(.degrees(-9))
                .offset(x: -91, y: 7)

            PhotoCard(image: "onboarding_desert", size: CGSize(width: 128, height: 164))
                .rotationEffect(.degrees(8))
                .offset(x: 91, y: 7)

            PhotoCard(image: "onboarding_wave", size: CGSize(width: 146, height: 190))
                .rotationEffect(.degrees(-2))
            
            ShowcaseBadge(
                text: "Bartek → Ola · 120 zł",
                icon: .avatar("B", Color(red: 0.478, green: 0.353, blue: 0.878))
            )
            .offset(x: 75, y: -43)

            ShowcaseBadge(text: "Lizbona za 12 dni", icon: .symbol("hourglass_top"))
                .offset(x: -86, y: 67)
        }
        .frame(height: 196)
    }
}

private struct FeatureCard: View {
    @Environment(\.theme) private var theme
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(icon)
                .resizable()
                .frame(width: 19, height: 19)
                .foregroundStyle(theme.accentStrong)
                .frame(width: 34, height: 34)
                .background(theme.accentTint, in: RoundedRectangle(cornerRadius: 11))
            Text(title)
                .typography(.calloutEmphasis)
                .foregroundStyle(.neutralInk)
                .padding(.top, Spacing.s8)
            Text(subtitle)
                .typography(.footnote)
                .foregroundStyle(.neutralGray)
                .padding(.top, 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(Spacing.s14)
        .background(.neutralWhite, in: RoundedRectangle(cornerRadius: Radius.lg))
    }
}

private struct FeaturesShowcase: View {
    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                FeatureCard(icon: "calendar_month", title: "Plan dzień po dniu", subtitle: "godziny, adresy, bilety")
                FeatureCard(icon: "payments", title: "Wspólna kasa", subtitle: "rozliczenia uczestników")
            }
            GridRow {
                FeatureCard(icon: "photo_library", title: "Jedna galeria", subtitle: "zdjęcia uczestników")
                FeatureCard(icon: "how_to_vote", title: "Głosowania", subtitle: "wspólne decyzje")
            }
        }
    }
}

struct WelcomeView: View {
    let onStart: () -> Void
    let onLogin: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            PhotoCollage()
                .padding(.top, 38)

            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text("zmykamy\(Text(".pl").foregroundStyle(theme.accent))")
                    .foregroundStyle(.neutralInk)
                    .typography(Typography(size: 15, weight: .bold, tracking: -0.2))
                Text("Planuj wyjazdy ze znajomymi w jednym miejscu.")
                    .typography(Typography(size: 30, weight: .heavy, tracking: -1))
                    .foregroundStyle(.neutralInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.s4)
            .padding(.top, 29)

            FeaturesShowcase()
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.s16)

            Spacer(minLength: Spacing.s24)

            VStack(spacing: Spacing.s4) {
                Button(action: onStart) {
                    HStack(spacing: Spacing.s6) {
                        Text("Rozpocznij")
                        Image("arrow_forward")
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(theme.accent, in: Capsule())
                }

                Button(action: onLogin) {
                    Text("Mam już konto")
                        .typography(.bodyEmphasis)
                        .foregroundStyle(theme.accentStrong)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, Spacing.gutter)
        .background { GradientOnboarding() }
    }
}

#Preview {
    WelcomeView(onStart: {}, onLogin: {})
}
