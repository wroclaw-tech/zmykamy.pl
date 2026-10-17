import SwiftUI

struct RootView: View {
    @State private var theme: Theme = .ocean

    var body: some View {
        WelcomeView(onStart: {}, onLogin: {})
            .environment(\.theme, theme)
            .tint(theme.accent)
    }
}

#Preview {
    RootView()
}
