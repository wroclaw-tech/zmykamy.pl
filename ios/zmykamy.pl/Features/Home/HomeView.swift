import SwiftUI

private struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .typography(.sectionLabel)
            .foregroundStyle(.neutralGray)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.s6)
    }
}

private struct ParticipantStack: View {
    let participants: [TripParticipant]
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: -7) {
            ForEach(participants) { participant in
                Text(participant.initial)
                    .typography(.captionBadge)
                    .foregroundStyle(.neutralWhite)
                    .frame(width: 26, height: 26)
                    .background(participant.color ?? theme.accent, in: .circle)
                    .overlay { Circle().strokeBorder(.neutralWhite, lineWidth: 2) }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct CurrentTripCard: View {
    let trip: UpcomingTrip

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 34)
        Color.clear
            .frame(height: 380)
            .overlay {
                Image(trip.image)
                    .resizable()
                    .scaledToFill()
            }
            .overlay(alignment: .topLeading) {
                HStack(spacing: Spacing.s6) {
                    Image(.sunny)
                        .resizable()
                        .frame(width: 18, height: 22)
                    Text(trip.status)
                        .typography(.subheadEmphasis)
                        .foregroundStyle(.neutralInk)
                }
                .padding(.horizontal, Spacing.s14)
                .frame(height: 34)
                .glassEffect(.regular, in: .capsule)
                .padding(Spacing.s14)
            }
            .overlay(alignment: .bottom) {
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.s4) {
                        Text(trip.title)
                            .typography(.title1)
                        Text(trip.subtitle)
                            .typography(.calloutRegular)
                            .foregroundStyle(.neutralInk2)
                        HStack(spacing: Spacing.s8) {
                            ParticipantStack(participants: trip.participants)
                            Text("\(trip.participants.count) osób")
                                .typography(.subheadRegular)
                                .foregroundStyle(.neutralInk2)
                        }
                        .padding(.top, Spacing.s6)
                    }
                    .foregroundStyle(.neutralInk)
                    Spacer()
                    Image(.chevronRight)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.neutralGray)
                }
                .padding(18)
                .glassEffect(.regular, in: .rect(cornerRadius: Radius.xl))
                .padding(10)
            }
            .clipShape(shape)
            .contentShape(shape)
            .shadow(color: Color(red: 0.369, green: 0.227, blue: 0.314).opacity(0.22), radius: 15, y: 14)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
    }
}

private struct TripRow: View {
    let trip: TripSummary
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: trip.thumbnail(theme), startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.title)
                    .typography(Typography(size: 17, weight: .semibold))
                    .foregroundStyle(.neutralInk)
                Text(trip.subtitle)
                    .typography(.subheadRegular)
                    .foregroundStyle(.neutralGray)
            }
            Spacer(minLength: Spacing.s8)
            badge
        }
        .padding(.horizontal, 14)
        .padding(.vertical, Spacing.s12)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var badge: some View {
        switch trip.badge {
        case .countdown(let text):
            Text(text)
                .typography(Typography(size: 13, weight: .semibold))
                .foregroundStyle(theme.accentStrong)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(theme.accentTint, in: .capsule)
        case .settled:
            HStack(spacing: Spacing.s4) {
                Image(.checkCircle)
                    .resizable()
                    .frame(width: 18, height: 18)
                Text("Rozliczony")
                    .typography(Typography(size: 13, weight: .semibold))
            }
            .foregroundStyle(theme.accentStrong)
        }
    }
}

private struct NewTripRow: View {
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(theme.accent.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .frame(width: 54, height: 54)
                    .overlay {
                        Image(.addRounded)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(theme.accent)
                    }
                Text("Nowy wyjazd")
                    .typography(Typography(size: 17, weight: .semibold))
                    .foregroundStyle(theme.accentStrong)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, Spacing.s12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct TripListCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 {
                        Rectangle()
                            .fill(.neutralInk2.opacity(0.12))
                            .frame(height: 0.5)
                    }
                    row
                }
            }
        }
        .background(.neutralWhite, in: .rect(cornerRadius: Radius.xl))
    }
}

struct HomeView: View {
    let user: AuthUser
    @Environment(AuthStore.self) private var auth
    @Environment(\.theme) private var theme
    @State private var isShowingAccount = false
    @State private var isShowingComingSoon = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.s8) {
                    SectionLabel(text: "NAJBLIŻSZY")
                    CurrentTripCard(trip: MockTrips.current)

                    SectionLabel(text: "ZAPLANOWANE")
                        .padding(.top, Spacing.s16)
                    TripListCard {
                        ForEach(MockTrips.planned) { TripRow(trip: $0) }
                        NewTripRow { isShowingComingSoon = true }
                    }

                    SectionLabel(text: "MINIONE")
                        .padding(.top, Spacing.s16)
                    TripListCard {
                        ForEach(MockTrips.past) { TripRow(trip: $0) }
                    }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.bottom, Spacing.s24)
            }
            .background { theme.background.ignoresSafeArea() }
            .navigationTitle("Wyjazdy")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Nowy wyjazd", image: .addRounded) { isShowingComingSoon = true }
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isShowingAccount = true } label: {
                        Text(String(user.name.prefix(1)).uppercased())
                            .typography(Typography(size: 17, weight: .bold))
                    }
                    .buttonStyle(.glassProminent)
                    .tint(theme.accent)
                    .accessibilityLabel("Konto")
                }
            }
            .confirmationDialog(user.email, isPresented: $isShowingAccount, titleVisibility: .visible) {
                Button("Wyloguj się", role: .destructive) {
                    Task { await auth.signOut() }
                }
            }
            .alert("Już wkrótce", isPresented: $isShowingComingSoon) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Tworzenie wyjazdów będzie dostępne wkrótce.")
            }
        }
    }
}

#Preview {
    HomeView(user: AuthUser(
        id: "preview",
        name: "Kuba",
        email: "kuba@zmykamy.pl",
        image: nil,
        themePalette: "ocean",
        termsVersion: AuthStore.currentTermsVersion,
        termsAcceptedAt: .now
    ))
    .environment(AuthStore())
}
