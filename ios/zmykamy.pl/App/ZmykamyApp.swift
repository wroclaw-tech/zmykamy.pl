import SwiftUI

@main
struct ZmykamyApp: App {
    @State private var auth = AuthStore()
    @State private var inviteRouter = InviteLinkRouter()

    init() {
        #if DEBUG
        // UI tests launch with this flag to start from a fresh install.
        if ProcessInfo.processInfo.arguments.contains("-resetState") {
            SessionStore().clear()
            OfflineCache.clear()
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-toolsPreview") {
                    ToolsPreview()
                } else {
                    RootView()
                }
                #else
                RootView()
                #endif
            }
                .environment(auth)
                .environment(inviteRouter)
                .onOpenURL { inviteRouter.open($0) }
        }
    }
}
