import Foundation

/// Drives the sign-in screen.
@Observable
final class SignInViewModel {

    enum Phase: Equatable {
        /// Typing an address.
        case editing
        /// Request in flight.
        case sending
        /// Link sent; waiting for the person to leave and come back.
        case sent(email: String)
    }

    var email: String = ""
    private(set) var phase: Phase = .editing
    private(set) var failure: AuthFailure?
    /// Seconds remaining before a resend is allowed. Zero means ready.
    private(set) var resendCooldown: Int = 0

    private let auth: AuthService
    private var cooldownTask: Task<Void, Never>?

    /// Long enough to stop someone hammering the button into a rate limit,
    /// short enough not to feel like a punishment when the first mail is slow.
    private static let cooldownSeconds = 30

    init(auth: AuthService) {
        self.auth = auth
    }

    /// Seam for previews and tests: lets the "check your email" state be shown
    /// without a live backend. Nothing in the app calls this.
    init(auth: AuthService, phase: Phase, email: String = "") {
        self.auth = auth
        self.phase = phase
        self.email = email
    }

    var canSubmit: Bool {
        phase != .sending && AuthService.normalizedEmail(email) != nil
    }

    var canResend: Bool {
        phase != .sending && resendCooldown == 0
    }

    func send() async {
        guard AuthService.normalizedEmail(email) != nil else {
            failure = .invalidEmail
            return
        }
        failure = nil
        phase = .sending

        do {
            try await auth.sendMagicLink(to: email)
            phase = .sent(email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
            startCooldown()
        } catch {
            failure = error
            phase = .editing
        }
    }

    func resend() async {
        guard canResend else { return }
        failure = nil
        let previous = phase
        phase = .sending
        do {
            try await auth.sendMagicLink(to: email)
            phase = previous
            startCooldown()
        } catch {
            failure = error
            phase = previous
        }
    }

    /// Back to the field, keeping what was typed so a typo is a quick fix.
    func editEmail() {
        cooldownTask?.cancel()
        resendCooldown = 0
        failure = nil
        phase = .editing
    }

    func clearFailure() {
        failure = nil
        auth.clearLinkFailure()
    }

    /// The loop captures `self` weakly, so it ends on its own within a second of
    /// the model going away. `deinit` is nonisolated under Swift 6 and cannot
    /// touch `cooldownTask`, so there is nothing to cancel there.
    private func startCooldown() {
        cooldownTask?.cancel()
        resendCooldown = Self.cooldownSeconds
        cooldownTask = Task { [weak self] in
            while let self, self.resendCooldown > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                self.resendCooldown -= 1
            }
        }
    }
}
