import SwiftUI

struct RootView: View {
    @Environment(AuthStore.self) private var auth
    @AppStorage("selectedClimate") private var selectedClimate: VacationClimate?

    private var theme: Theme {
        let userClimate = auth.user?.themePalette.flatMap(VacationClimate.init(rawValue:))
        return (userClimate ?? selectedClimate ?? .ocean).theme
    }

    var body: some View {
        ZStack {
            switch auth.state {
            case .restoring:
                theme.background.ignoresSafeArea()
            case .signedOut:
                OnboardingFlow(climate: $selectedClimate)
                    .transition(.opacity)
            case .signedIn(let user):
                HomeView(user: user, auth: auth)
                    .transition(.opacity)
            }
        }
        .animation(.smooth, value: auth.state)
        .environment(\.theme, theme)
        .tint(theme.accent)
        .task { await auth.restore() }
    }
}

#Preview {
    RootView()
        .environment(AuthStore())
}
