import Foundation
import Supabase

/// Everything that can go wrong signing in, phrased for a person.
enum AuthFailure: Error, Equatable, Sendable {
    case notConfigured
    case invalidEmail
    /// Shorter than ``AuthService/minimumPasswordLength``.
    case weakPassword
    /// Sign-up hit an address that already has an account.
    case emailAlreadyRegistered
    /// Sign-in: the pair did not match. Deliberately does not say which half.
    case invalidCredentials
    /// The project requires email confirmation and this address has not done it.
    case emailNotConfirmed
    case network
    case rateLimited
    case unknown(String)

    var message: String {
        switch self {
        case .notConfigured:
            "The app isn't connected to its backend yet."
        case .invalidEmail:
            "That doesn't look like an email address."
        case .weakPassword:
            "Passwords need at least \(AuthService.minimumPasswordLength) characters."
        case .emailAlreadyRegistered:
            "There's already an account with that email. Sign in instead."
        case .invalidCredentials:
            // Never "wrong password" or "no such account": saying which half was
            // wrong tells anyone with a list of addresses which ones are real.
            "That email and password don't match an account."
        case .emailNotConfirmed:
            "Confirm your email address first — check your inbox for the link."
        case .network:
            "You're offline. Reconnect and try again."
        case .rateLimited:
            "Too many attempts. Wait a minute, then try again."
        case .unknown:
            "Something went wrong. Try again."
        }
    }

    /// Whether the message belongs under the email field rather than the password.
    var isAboutEmail: Bool {
        switch self {
        case .invalidEmail, .emailAlreadyRegistered, .emailNotConfirmed: true
        default: false
        }
    }
}

/// Session state, and email + password auth.
///
/// Email and password is the whole method — no magic link, no third-party
/// providers. Supabase handles the hashing and the session; the app holds a
/// password only for as long as it takes to post it.
///
/// The row in `public.profiles` is created by the `on_auth_user_created`
/// trigger, which fires on insert into `auth.users` and so covers an email
/// sign-up like any other. ``ensureProfileExists(userID:)`` stays as a
/// belt-and-braces no-op for rows that predate the trigger.
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

    /// The app's own floor, and stricter than Supabase's default of 6.
    ///
    /// Stated on screen before anyone types, not discovered by being rejected.
    /// Set the dashboard to match — see `supabase/README.md`.
    ///
    /// `nonisolated` so `AuthFailure.message` can quote it: the failure enum is
    /// a plain Sendable value and is read from wherever an error surfaces.
    nonisolated static let minimumPasswordLength = 8

    private(set) var sessionState: SessionState = .loading

    private let client: SupabaseClient?

    /// Guards against `start()` spinning up a second listener. There is
    /// deliberately no `deinit` cancelling this: `deinit` is nonisolated under
    /// Swift 6 and cannot read main-actor state, and the cancel is unnecessary
    /// anyway — the task captures `self` weakly, so it neither retains this
    /// object nor outlives it past the next auth event.
    @ObservationIgnored private var listenerTask: Task<Void, Never>?

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

    // MARK: - Sign up

    /// What happened after a sign-up.
    enum SignUpOutcome: Equatable, Sendable {
        /// Session in hand — the normal path when email confirmation is off.
        case signedIn
        /// The project requires confirmation, so there is no session until the
        /// person opens the link. The screen has to say so rather than looking
        /// like nothing happened.
        case needsEmailConfirmation(email: String)
    }

    @discardableResult
    func signUp(email: String, password: String) async throws(AuthFailure) -> SignUpOutcome {
        guard let client else { throw AuthFailure.notConfigured }
        guard let address = Self.normalizedEmail(email) else { throw AuthFailure.invalidEmail }
        guard Self.isAcceptablePassword(password) else { throw AuthFailure.weakPassword }

        do {
            let response = try await client.auth.signUp(email: address, password: password)
            // `session` is nil exactly when the project requires confirmation.
            return response.session == nil
                ? .needsEmailConfirmation(email: address)
                : .signedIn
        } catch {
            throw Self.translate(error)
        }
    }

    // MARK: - Sign in

    func signIn(email: String, password: String) async throws(AuthFailure) {
        guard let client else { throw AuthFailure.notConfigured }
        guard let address = Self.normalizedEmail(email) else { throw AuthFailure.invalidEmail }
        // No length check here on purpose: an existing account may predate the
        // app's floor, and rejecting it locally would lock someone out of their
        // own account with a message about password strength.
        guard !password.isEmpty else { throw AuthFailure.invalidCredentials }

        do {
            try await client.auth.signIn(email: address, password: password)
        } catch {
            throw Self.translate(error)
        }
    }

    func signOut() async {
        guard let client else {
            sessionState = .signedOut
            return
        }
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

    // MARK: - Validation

    /// Lowercased and trimmed, with a deliberately loose shape check — email
    /// validation beyond "has one @ with something either side" rejects valid
    /// addresses, and the real check is whether signing in works.
    static func normalizedEmail(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.contains(" ") else { return nil }
        let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, parts[1].contains(".") else { return nil }
        guard let last = parts[1].split(separator: ".").last, last.count >= 2 else { return nil }
        return trimmed
    }

    /// Length only.
    ///
    /// No character-class rules: they push people towards `Password1!` and are
    /// worse than length, which is the one requirement worth stating up front
    /// because it is the one somebody can act on while typing.
    static func isAcceptablePassword(_ password: String) -> Bool {
        password.count >= minimumPasswordLength
    }

    // MARK: - Errors

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
            case .api(let message, let errorCode, _, let response):
                return fromAPI(message: message, code: errorCode.rawValue, status: response.statusCode)
            case .sessionMissing:
                return .invalidCredentials
            default:
                return .unknown(authError.localizedDescription)
            }
        }

        return .unknown(error.localizedDescription)
    }

    /// Maps GoTrue's answer onto something worth reading.
    ///
    /// Matched on `code` rather than on the message, which is English prose the
    /// server is free to reword. The message is only consulted as a fallback for
    /// older responses that carry no code at all.
    private static func fromAPI(message: String, code: String, status: Int) -> AuthFailure {
        switch code {
        case "user_already_exists", "email_exists":
            return .emailAlreadyRegistered
        case "invalid_credentials":
            return .invalidCredentials
        case "weak_password":
            return .weakPassword
        case "email_not_confirmed":
            return .emailNotConfirmed
        case "over_request_rate_limit", "over_email_send_rate_limit":
            return .rateLimited
        case "validation_failed":
            return .invalidEmail
        default:
            break
        }

        if status == 429 { return .rateLimited }

        let lowered = message.lowercased()
        if lowered.contains("already registered") || lowered.contains("already exists") {
            return .emailAlreadyRegistered
        }
        if lowered.contains("invalid login credentials") {
            return .invalidCredentials
        }
        if lowered.contains("password") && lowered.contains("least") {
            return .weakPassword
        }
        if lowered.contains("not confirmed") {
            return .emailNotConfirmed
        }
        if status == 400 || status == 401 { return .invalidCredentials }

        return .unknown(message)
    }
}
