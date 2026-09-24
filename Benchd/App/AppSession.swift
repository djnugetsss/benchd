import Foundation

/// Owns the app's top-level state: who is signed in, and whether they have
/// finished connecting Sleeper.
///
/// `route` is computed rather than stored, so it cannot drift from the auth
/// state it is derived from. Observation propagates through `auth`, so a view
/// reading `route` updates when the session changes.
@Observable
final class AppSession {

    enum Route: Equatable {
        /// Restoring a stored session, or checking for a connected account.
        case launching
        case onboarding(startingAt: OnboardingStep)
        /// Connected, but the history has never finished coming down.
        case firstSync(accountID: UUID)
        case main
    }

    enum ConnectionState: Equatable {
        case unknown
        case checking
        case none
        case connected(SleeperAccount)
    }

    let auth: AuthService
    private let accounts: SleeperAccountService
    private let profiles: ProfileService

    private(set) var connectionState: ConnectionState = .unknown

    /// Bumped whenever a sync finishes. Screens that show synced data key their
    /// reload off this, so a background refresh lands without the person having
    /// to leave the tab or restart the app.
    private(set) var syncGeneration: Int = 0

    init(
        auth: AuthService = AuthService(),
        accounts: SleeperAccountService = SleeperAccountService(),
        profiles: ProfileService = ProfileService()
    ) {
        self.auth = auth
        self.accounts = accounts
        self.profiles = profiles
    }

    var route: Route {
        switch auth.sessionState {
        case .loading:
            .launching
        case .signedOut:
            .onboarding(startingAt: .welcome)
        case .signedIn:
            switch connectionState {
            case .unknown, .checking:
                // Hold on the launch screen rather than flashing onboarding at
                // someone who is already fully set up.
                .launching
            case .none:
                .onboarding(startingAt: .connectSleeper)
            case .connected(let account):
                // `last_synced_at` is only set once a run finishes, so this is
                // precisely "has never completed a sync". Later refreshes run in
                // the background and never send anyone back to this screen.
                account.lastSyncedAt == nil
                    ? .firstSync(accountID: account.id)
                    : .main
            }
        }
    }

    /// The connected Sleeper account, when there is one.
    var connectedAccount: SleeperAccount? {
        if case .connected(let account) = connectionState { return account }
        return nil
    }

    func start() {
        auth.start()
    }

    /// Called whenever the auth state settles. Cheap and idempotent.
    func refreshConnectionState() async {
        guard let profileID = auth.sessionState.userID else {
            connectionState = .unknown
            return
        }

        // Only show the checking hold on a first look; a refresh after a sync
        // should not bounce the UI back to the launch screen.
        if connectionState == .unknown { connectionState = .checking }

        do {
            let all = try await accounts.accounts(for: profileID)
            connectionState = all.first.map(ConnectionState.connected) ?? .none
        } catch {
            // Treat a failed check as "not connected": onboarding's connect step
            // can retry and report a real error, whereas the launch screen has
            // nowhere to put one and would just hang.
            connectionState = .none
        }
    }

    func markSleeperConnected(_ account: SleeperAccount) {
        connectionState = .connected(account)
    }

    /// Called when the first sync reports completion. Re-reads the account
    /// rather than assuming: the edge function stamps `last_synced_at` before
    /// it emits the completion event, so the truth is already in Postgres.
    func markSyncComplete() async {
        await refreshConnectionState()
        syncGeneration += 1
    }

    /// Called when the app returns to the foreground. A sync may have completed
    /// server-side while we were away.
    func refreshAfterForeground() async {
        await refreshConnectionState()
        syncGeneration += 1
    }

    /// Stamps `profiles.last_seen_at`, which is what the hourly scheduler uses
    /// to decide an account is still worth refreshing. Without this every
    /// account would look abandoned after 30 days.
    func touchLastSeen() async {
        guard let profileID = auth.sessionState.userID else { return }
        await profiles.touchLastSeen(profileID: profileID)
    }

    func signOut() async {
        await auth.signOut()
        connectionState = .unknown
    }
}
