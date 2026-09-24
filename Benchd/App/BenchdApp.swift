import SwiftUI

@main
struct BenchdApp: App {
    @State private var session = AppSession()

    init() {
        // The navigation bar is UIKit underneath and has to be styled through
        // its appearance proxy, before any bar exists. See NavigationAppearance.
        NavigationAppearance.apply()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                // Starts the auth listener, which restores a stored session on
                // launch and routes on every later change. See AuthService.start().
                .task { session.start() }
        }
    }
}
