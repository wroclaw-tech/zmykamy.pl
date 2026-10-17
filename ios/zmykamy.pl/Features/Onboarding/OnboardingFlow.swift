import SwiftUI

private enum OnboardingStep: Hashable {
    case welcome
    case climate
    case permissions
    case auth(AuthMode)
}

struct OnboardingFlow: View {
    @Binding var climate: VacationClimate?
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var step: OnboardingStep?

    var body: some View {
        ZStack {
            switch step ?? (hasCompletedOnboarding ? .auth(.signIn) : .welcome) {
            case .welcome:
                WelcomeView(
                    onStart: { go(to: .climate) },
                    onLogin: { finish(with: .signIn) }
                )
                .transition(.push(from: .trailing))
            case .climate:
                ClimateView(
                    selection: $climate,
                    onContinue: { go(to: .permissions) },
                    onSkip: { finish(with: .signUp) }
                )
                .transition(.push(from: .trailing))
            case .permissions:
                PermissionsView(onFinish: { finish(with: .signUp) })
                    .transition(.push(from: .trailing))
            case .auth(let mode):
                AuthView(mode: mode, climate: climate)
                    .transition(.push(from: .trailing))
            }
        }
    }

    private func go(to next: OnboardingStep) {
        withAnimation(.smooth) { step = next }
    }

    private func finish(with mode: AuthMode) {
        hasCompletedOnboarding = true
        go(to: .auth(mode))
    }
}

#Preview {
    @Previewable @State var climate: VacationClimate?
    OnboardingFlow(climate: $climate)
        .environment(AuthStore())
        .environment(\.theme, climate?.theme ?? .ocean)
}
