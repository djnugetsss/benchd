import Foundation
import Supabase

/// Everything that can go wrong signing in, phrased for a person.
enum AuthFailure: Error, Equatable, Sendable {
    case notConfigured
    case invalidEmail
    case network
    case rateLimited
    /// The tapped link was consumed already, expired, or is not ours.
    case invalidOrExpiredLink
    case unknown(String)

    var message: String {
        switch self {
        case .notConfigured:
            "The app isn't connected to its backend yet."
        case .invalidEmail:
            "That doesn't look like an email address."
        case .network:
            "You're offline. Reconnect and try again."
        case .rateLimited:
            "Too many links requested. Wait a minute, then try again."
        case .invalidOrExpiredLink:
            "That link has expired or was already used. Send yourself a fresh one."
        case .unknown:
            "Something went wrong. Try again."
        }
    }
}

/// Session state and the magic-link flow.
///
/// Magic link is the only method in v1 — no passwords, no Sign in with Apple.
/// That keeps onboarding to a single field and means there is no password reset
/// flow to design.
@Observable
final class AuthService {

    enum SessionState: Equatable {
        /// Before the stored session (if any) has been restored.
        case loading
        case signedOut
        case signedIn(userID: UUID)

        var userID: UUID? {
            if case .signedIn(let id) = self { id } else { nil }
        }
    }

    private(set) var sessionState: SessionState = .loading

    /// Set when a tapped magic link fails to produce a session. Surfaced by the
    /// sign-in screen so an expired link is explained rather than silently
    /// dropping the person back on the email field.
    private(set) var lastLinkFailure: AuthFailure?

    private let client: SupabaseClient?
    /// Guards against `start()` spinning up a second listener. There is
    /// deliberately no `deinit` cancelling this: `deinit` is nonisolated under
    /// Swift 6 and cannot read main-actor state, and the cancel is unnecessary
    /// anyway — the task captures `self` weakly, so it neither retains this
    /// object nor outlives it past the next auth event.
    @ObservationIgnored private var listenerTask: Task<Void, Never>?

    /// The deep link Supabase sends people back to. Must match both the URL type
    /// in Info.plist and the allowed redirect list in the Supabase dashboard.
    static let redirectURL = URL(string: "benchd://auth-callback")!

    init(client: SupabaseClient? = SupabaseClientProvider.shared) {
        self.client = client
        if client == nil {
            // No credentials in Secrets.xcconfig — don't sit on a spinner forever.
            sessionState = .signedOut
        }
    }

    // MARK: - Lifecycle

    /// Begins observing auth state. Safe to call more than once.
    func start() {
        guard let client, listenerTask == nil else { return }

        listenerTask = Task { [weak self] in
            for await (event, session) in client.auth.authStateChanges {
                guard let self else { return }
                await self.apply(event: event, session: session)
            }
        }
    }

    private func apply(event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .signedOut:
            sessionState = .signedOut
        case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
            if let session {
                sessionState = .signedIn(userID: session.user.id)
                lastLinkFailure = nil
                // The database trigger normally creates this. The call is a
                // no-op safety net for accounts that predate the trigger.
                try? await ensureProfileExists(userID: session.user.id)
            } else {
                sessionState = .signedOut
            }
        default:
            break
        }
    }

    // MARK: - Magic link

    func sendMagicLink(to email: String) async throws(AuthFailure) {
        guard let client else { throw AuthFailure.notConfigured }
        guard let address = Self.normalizedEmail(email) else {
            throw AuthFailure.invalidEmail
        }

        do {
            try await client.auth.signInWithOTP(
                email: address,
                redirectTo: Self.redirectURL
            )
        } catch {
            throw Self.translate(error)
        }
    }

    /// Exchanges a tapped magic link for a session.
    func handle(url: URL) async {
        guard let client else { return }
        do {
            _ = try await client.auth.session(from: url)
            lastLinkFailure = nil
        } catch {
            let failure = Self.translate(error)
            // A link that fails to exchange is almost always expired or reused;
            // say that rather than "unknown error".
            lastLinkFailure = failure == .unknown("") ? .invalidOrExpiredLink : failure
            if case .unknown = failure { lastLinkFailure = .invalidOrExpiredLink }
        }
    }

    func clearLinkFailure() { lastLinkFailure = nil }

    func signOut() async {
        guard let client else { return }
        try? await client.auth.signOut()
        sessionState = .signedOut
    }

    // MARK: - Profile

    private struct ProfileSeed: Encodable {
        let id: UUID
    }

    /// Idempotent. The `on_auth_user_created` trigger is the primary mechanism;
    /// this exists so a missing row can never wedge onboarding.
    func ensureProfileExists(userID: UUID) async throws {
        guard let client else { return }
        try await client
            .from("profiles")
            .upsert(ProfileSeed(id: userID), onConflict: "id", ignoreDuplicates: true)
            .execute()
    }

    // MARK: - Helpers

    /// Lowercased and trimmed, with a deliberately loose shape check — email
    /// validation beyond "has one @ with something either side" rejects valid
    /// addresses, and the real check is whether the link arrives.
    static func normalizedEmail(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.contains(" ") else { return nil }
        let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, parts[1].contains(".") else { return nil }
        guard let last = parts[1].split(separator: ".").last, last.count >= 2 else { return nil }
        return trimmed
    }

    static func translate(_ error: any Error) -> AuthFailure {
        if error is CancellationError { return .unknown("cancelled") }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return .network
            default:
                return .unknown(urlError.localizedDescription)
            }
        }

        if let authError = error as? AuthError {
            switch authError {
            case .api(_, let errorCode, _, let response):
                if response.statusCode == 429 || errorCode == .overRequestRateLimit {
                    return .rateLimited
                }
                if response.statusCode == 401 || response.statusCode == 403 {
                    return .invalidOrExpiredLink
                }
                return .unknown(authError.localizedDescription)
            case .pkceGrantCodeExchange, .implicitGrantRedirect, .sessionMissing:
                return .invalidOrExpiredLink
            default:
                return .unknown(authError.localizedDescription)
            }
        }

        return .unknown(error.localizedDescription)
    }
}
