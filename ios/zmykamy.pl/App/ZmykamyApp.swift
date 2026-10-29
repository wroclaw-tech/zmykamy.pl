import SwiftUI

@main
struct ZmykamyApp: App {
    @State private var auth = AuthStore()
    @State private var inviteRouter = InviteLinkRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(inviteRouter)
                .onOpenURL { inviteRouter.open($0) }
        }
    }
}
