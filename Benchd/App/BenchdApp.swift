import SwiftUI

@main
struct BenchdApp: App {
    @State private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .task { session.start() }
                // Supabase sends people back to benchd://auth-callback after
                // they tap the magic link. The URL carries the token that gets
                // exchanged for a session — see AuthService.handle(url:).
                .onOpenURL { url in
                    Task { await session.handle(url: url) }
                }
        }
    }
}
