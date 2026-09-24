import AuthenticationServices
import CryptoKit
import Foundation
import Supabase

/// Everything that can go wrong signing in, phrased for a person.
enum AuthFailure: Error, Equatable, Sendable {
    case notConfigured
    /// The Apple sheet was dismissed. Not a failure — the screen says nothing.
    case cancelled
    /// Apple answered, but without the identity token the exchange needs.
    case appleUnavailable
    /// This Apple ID was disconnected from Benchd in iOS Settings.
    case appleRevoked
    case network
    case rateLimited
    case unknown(String)

    var message: String {
        switch self {
        case .notConfigured:
            "The app isn't connected to its backend yet."
        case .cancelled:
            // Never shown. Backing out of a sheet is an answer, not an error.
            ""
        case .appleUnavailable:
            "Apple couldn't complete that sign-in. Try again in a moment."
        case .appleRevoked:
            "Your Apple ID was disconnected from Benchd. Sign in again to carry on."
        case .network:
            "You're offline. Reconnect and try again."
        case .rateLimited:
            "Too many attempts. Wait a minute, then try again."
        case .unknown:
            "Something went wrong. Try again."
        }
    }

    /// Whether the sign-in screen should show anything at all.
    var isWorthShowing: Bool { self != .cancelled }
}

/// Session state and Sign in with Apple.
///
/// Apple is the only method: one tap, no password to reset, no email round trip,
/// and nothing to type on a phone. Supabase verifies Apple's identity token
/// server-side via `signInWithIdToken`, so the app never handles a password or a
/// long-lived secret.
///
/// The row in `public.profiles` is created by the `on_auth_user_created` trigger,
/// which fires on insert into `auth.users` regardless of how the account was
/// made — Apple sign-ins included. ``ensureProfileExists(userID:)`` stays as a
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

    private(set) var sessionState: SessionState = .loading

    /// Set when a session ends for a reason worth explaining — today only a
    /// revoked Apple credential. Surfaced on the sign-in screen so someone who
    /// was signed in a second ago is told why they are not any more.
    private(set) var lastSessionFailure: AuthFailure?

    private let client: SupabaseClient?

    /// Guards against `start()` spinning up a second listener. There is
    /// deliberately no `deinit` cancelling these: `deinit` is nonisolated under
    /// Swift 6 and cannot read main-actor state, and the cancel is unnecessary
    /// anyway — the tasks capture `self` weakly, so they neither retain this
    /// object nor outlive it past the next event.
    @ObservationIgnored private var listenerTask: Task<Void, Never>?
    @ObservationIgnored private var revocationTask: Task<Void, Never>?

    /// Apple's own identifier for this user, kept so the credential can be
    /// re-checked on launch. It is not a secret — it is scoped to this app and
    /// useless anywhere else — which is why `UserDefaults` is the right home.
    @ObservationIgnored private let defaults: UserDefaults
    private static let appleUserIDKey = "auth.appleUserID"

    init(
        client: SupabaseClient? = SupabaseClientProvider.shared,
        defaults: UserDefaults = .standard
    ) {
        self.client = client
        self.defaults = defaults
        if client == nil {
            // No credentials in Secrets.xcconfig — don't sit on a spinner forever.
            sessionState = .signedOut
        }
    }

    // MARK: - Lifecycle

    /// Begins observing auth state and Apple credential revocation. Safe to call
    /// more than once.
    func start() {
        startSessionListener()
        startRevocationListener()
        Task { await verifyAppleCredential() }
    }

    private func startSessionListener() {
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
                lastSessionFailure = nil
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

    // MARK: - Sign in with Apple

    /// Everything the token exchange needs out of Apple's answer.
    struct AppleCredential: Equatable, Sendable {
        let idToken: String
        /// Apple's stable, app-scoped user identifier.
        let userID: String
        /// Given **only** on the very first authorization, and only if the person
        /// agreed to share it. Every later sign-in returns nil, which is why the
        /// name is written to the profile on sight rather than compared first.
        let fullName: PersonNameComponents?
    }

    /// Unwraps `ASAuthorization` into the pieces the exchange needs.
    ///
    /// Static and pure so the awkward shapes — a credential of the wrong type, a
    /// missing identity token — are unit testable without an Apple sheet.
    static func appleCredential(
        from authorization: ASAuthorization
    ) throws(AuthFailure) -> AppleCredential {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthFailure.appleUnavailable
        }
        guard
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8),
            !idToken.isEmpty
        else {
            throw AuthFailure.appleUnavailable
        }

        return AppleCredential(
            idToken: idToken,
            userID: credential.user,
            fullName: credential.fullName
        )
    }

    /// Exchanges Apple's identity token for a Supabase session.
    ///
    /// `rawNonce` is the unhashed nonce. Apple's token carries its SHA-256, and
    /// Supabase hashes what it is given to compare — sending the hash here
    /// instead is the single most common way this integration fails, with a
    /// completely unhelpful error.
    ///
    /// Note what is *not* required: an email address. Apple hides it behind a
    /// private relay whenever the person chooses to, and Benchd never needs it —
    /// there is nothing in the app that sends mail.
    func signInWithApple(_ credential: AppleCredential, rawNonce: String) async throws(AuthFailure) {
        guard let client else { throw AuthFailure.notConfigured }

        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: credential.idToken, nonce: rawNonce)
            )

            defaults.set(credential.userID, forKey: Self.appleUserIDKey)
            lastSessionFailure = nil

            // Apple hands over the name once, on the first authorization ever.
            // If it is not written now it is gone for good, so this is not
            // conditional on the profile being empty.
            if let name = Self.displayName(from: credential.fullName) {
                await setDisplayName(name, userID: session.user.id)
            }
        } catch {
            throw Self.translate(error)
        }
    }

    /// "Ansh Mehta" from Apple's name components, or nil when there is nothing
    /// usable in them — which is the normal case on every sign-in after the first.
    static func displayName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatted = PersonNameComponentsFormatter.localizedString(
            from: components, style: .default
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return formatted.isEmpty ? nil : formatted
    }

    // MARK: - Revocation

    /// Apple posts this when someone disconnects the app in iOS Settings while
    /// it is running.
    private func startRevocationListener() {
        guard revocationTask == nil else { return }

        revocationTask = Task { [weak self] in
            let revoked = NotificationCenter.default.notifications(
                named: ASAuthorizationAppleIDProvider.credentialRevokedNotification
            )
            for await _ in revoked {
                guard let self else { return }
                await self.handleRevokedCredential()
            }
        }
    }

    /// The other half: a revocation that happened while the app was closed is
    /// only discoverable by asking. Without this someone who disconnected Benchd
    /// yesterday opens it today still signed in.
    private func verifyAppleCredential() async {
        guard let appleUserID = defaults.string(forKey: Self.appleUserIDKey) else { return }

        let state = try? await ASAuthorizationAppleIDProvider()
            .credentialState(forUserID: appleUserID)

        if state == .revoked || state == .notFound {
            await handleRevokedCredential()
        }
    }

    private func handleRevokedCredential() async {
        defaults.removeObject(forKey: Self.appleUserIDKey)
        await signOut()
        // Set after signing out: `signOut` clears it, and the point of this
        // failure is that it survives long enough to be read on the sign-in
        // screen the person is about to land on.
        lastSessionFailure = .appleRevoked
    }

    func clearSessionFailure() { lastSessionFailure = nil }

    // MARK: - Sign out

    func signOut() async {
        defaults.removeObject(forKey: Self.appleUserIDKey)
        lastSessionFailure = nil
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

    private struct DisplayNameUpdate: Encodable {
        let displayName: String
        enum CodingKeys: String, CodingKey { case displayName = "display_name" }
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

    /// Silent on failure: a missing display name is cosmetic, and there is
    /// nothing useful to say to someone whose name did not save during sign-in.
    private func setDisplayName(_ name: String, userID: UUID) async {
        guard let client else { return }
        _ = try? await client
            .from("profiles")
            .update(DisplayNameUpdate(displayName: name))
            .eq("id", value: userID)
            .execute()
    }

    // MARK: - Errors

    static func translate(_ error: any Error) -> AuthFailure {
        if error is CancellationError { return .cancelled }

        if let authorizationError = error as? ASAuthorizationError {
            switch authorizationError.code {
            case .canceled: return .cancelled
            case .failed, .invalidResponse, .notHandled: return .appleUnavailable
            case .notInteractive: return .appleUnavailable
            default: return .appleUnavailable
            }
        }

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
                return .unknown(authError.localizedDescription)
            case .sessionMissing:
                return .appleUnavailable
            default:
                return .unknown(authError.localizedDescription)
            }
        }

        return .unknown(error.localizedDescription)
    }
}

// MARK: - Nonce

/// The nonce that ties one Apple sign-in to one token exchange.
///
/// Apple signs the **hash** into the identity token; Supabase is given the raw
/// value and hashes it to compare. That asymmetry is the whole point: a token
/// captured in transit cannot be replayed without the raw nonce, which never
/// leaves the device except in the one exchange it was minted for.
nonisolated enum AppleNonce {

    /// A fresh random nonce. 32 characters from an unambiguous alphabet — long
    /// enough that guessing is hopeless, short enough to read in a log.
    static func random(length: Int = 32) -> String {
        precondition(length > 0)
        let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        result.reserveCapacity(length)

        for _ in 0..<length {
            // `SystemRandomNumberGenerator` is the platform CSPRNG. Using it
            // through `randomElement` keeps this free of the SecRandomCopyBytes
            // dance without weakening it.
            var generator = SystemRandomNumberGenerator()
            result.append(alphabet.randomElement(using: &generator)!)
        }
        return result
    }

    /// The lowercase hex SHA-256 of `input`, which is what goes on the request.
    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
