import SwiftUI

@main
struct BenchdApp: App {
    @State private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                // Starts the auth listener and re-checks the Apple credential,
                // which is how a sign-in revoked while the app was closed is
                // noticed. See AuthService.start().
                .task { session.start() }
        }
    }
}
