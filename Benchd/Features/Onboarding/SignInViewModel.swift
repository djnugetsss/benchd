import AuthenticationServices
import Foundation

/// Drives the sign-in screen.
///
/// The whole flow is two calls: hand Apple a request carrying a hashed nonce,
/// then hand Apple's answer to Supabase along with the raw one. The nonce is
/// held here, between those two moments, and nowhere else.
@Observable
final class SignInViewModel {

    enum Phase: Equatable {
        case idle
        /// Apple's sheet is up, or the token is being exchanged.
        case authenticating
    }

    private(set) var phase: Phase = .idle
    private(set) var ownFailure: AuthFailure?

    /// The raw nonce for the request in flight. Cleared as soon as it is spent —
    /// a nonce that outlives its exchange is the thing it exists to prevent.
    @ObservationIgnored private var pendingNonce: String?

    private let auth: AuthService

    init(auth: AuthService) {
        self.auth = auth
    }

    /// Seam for previews and tests. Nothing in the app calls this.
    init(auth: AuthService, phase: Phase, failure: AuthFailure? = nil) {
        self.auth = auth
        self.phase = phase
        self.ownFailure = failure
    }

    /// What the screen shows.
    ///
    /// A revoked credential is reported by `AuthService`, not by this screen's
    /// own attempt, but it lands here — someone whose Apple ID was disconnected
    /// arrives on this screen and is owed the reason.
    var failure: AuthFailure? {
        let candidate = ownFailure ?? auth.lastSessionFailure
        guard let candidate, candidate.isWorthShowing else { return nil }
        return candidate
    }

    var isAuthenticating: Bool { phase == .authenticating }

    // MARK: - The two halves of an Apple sign-in

    /// Called as the sheet opens.
    ///
    /// `fullName` and `email` are both requested, and neither is required.
    /// Apple's private relay means the address may be a forwarding one, and the
    /// name arrives only on the first authorization — Benchd sends no mail and
    /// shows no name it was not given, so either being withheld is fine.
    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        let raw = AppleNonce.random()
        pendingNonce = raw

        request.requestedScopes = [.fullName, .email]
        request.nonce = AppleNonce.sha256(raw)

        ownFailure = nil
        auth.clearSessionFailure()
        phase = .authenticating
    }

    /// Called when the sheet closes, whichever way it went.
    func handle(_ result: Result<ASAuthorization, any Error>) async {
        defer { phase = .idle }

        switch result {
        case .failure(let error):
            let failure = AuthService.translate(error)
            // Backing out of the sheet is an answer, not an error. The screen
            // goes back to how it was and says nothing.
            ownFailure = failure.isWorthShowing ? failure : nil

        case .success(let authorization):
            guard let rawNonce = pendingNonce else {
                // No nonce means this answer belongs to a request we did not
                // make, and it cannot be exchanged safely.
                ownFailure = .appleUnavailable
                return
            }
            pendingNonce = nil

            do {
                let credential = try AuthService.appleCredential(from: authorization)
                try await auth.signInWithApple(credential, rawNonce: rawNonce)
            } catch let failure as AuthFailure {
                ownFailure = failure.isWorthShowing ? failure : nil
            } catch {
                ownFailure = .unknown(error.localizedDescription)
            }
        }
    }

    func dismissFailure() {
        ownFailure = nil
        auth.clearSessionFailure()
    }
}
