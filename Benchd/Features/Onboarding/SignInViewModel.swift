import Foundation

/// Drives the sign-in screen.
///
/// One screen does both jobs. Creating an account and signing in take the same
/// two fields, and splitting them into two screens would mean guessing which one
/// somebody wants before they have told you.
@Observable
final class SignInViewModel {

    enum Mode: Equatable {
        case signUp
        case signIn

        var title: String {
            switch self {
            case .signUp: "Create your account"
            case .signIn: "Welcome back"
            }
        }

        var subtitle: String {
            switch self {
            case .signUp: "An email and a password. That's the whole sign-up."
            case .signIn: "Sign in and your career comes back with you."
            }
        }

        var action: String {
            switch self {
            case .signUp: "Create account"
            case .signIn: "Sign in"
            }
        }

        /// The prompt for the other mode, as one sentence.
        var switchPrompt: String {
            switch self {
            case .signUp: "Already have an account? Sign in"
            case .signIn: "New here? Create an account"
            }
        }

        var toggled: Mode {
            switch self {
            case .signUp: .signIn
            case .signIn: .signUp
            }
        }
    }

    enum Phase: Equatable {
        case editing
        case submitting
        /// Signed up, but the project requires a confirmation click first.
        case awaitingConfirmation(email: String)
    }

    var email: String = ""
    var password: String = ""

    private(set) var mode: Mode = .signUp
    private(set) var phase: Phase = .editing
    private(set) var failure: AuthFailure?

    /// Set once someone has tried. Until then the fields stay quiet — marking an
    /// address invalid while it is still being typed is the most common way a
    /// form nags.
    private(set) var hasAttempted = false

    private let auth: AuthService

    init(auth: AuthService) {
        self.auth = auth
    }

    /// Seam for previews and tests. Nothing in the app calls this.
    init(
        auth: AuthService,
        mode: Mode = .signUp,
        phase: Phase = .editing,
        email: String = "",
        password: String = "",
        failure: AuthFailure? = nil
    ) {
        self.auth = auth
        self.mode = mode
        self.phase = phase
        self.email = email
        self.password = password
        self.failure = failure
        self.hasAttempted = failure != nil
    }

    // MARK: - Derived state

    var isSubmitting: Bool { phase == .submitting }

    var canSubmit: Bool {
        guard phase != .submitting else { return false }
        guard AuthService.normalizedEmail(email) != nil else { return false }
        return switch mode {
        case .signUp: AuthService.isAcceptablePassword(password)
        case .signIn: !password.isEmpty
        }
    }

    /// The rule, stated before anyone is told off by it.
    var passwordRequirement: String? {
        mode == .signUp
            ? "At least \(AuthService.minimumPasswordLength) characters."
            : nil
    }

    /// Live while typing: the only requirement is length, so it can be checked
    /// on every keystroke without guessing at intent.
    var passwordHasError: Bool {
        if failure == .weakPassword { return true }
        guard mode == .signUp, !password.isEmpty else { return false }
        return !AuthService.isAcceptablePassword(password)
    }

    /// Only after a submission: a half-typed address is not an error.
    var emailHasError: Bool {
        if failure?.isAboutEmail == true { return true }
        guard hasAttempted, !email.isEmpty else { return false }
        return AuthService.normalizedEmail(email) == nil
    }

    // MARK: - Actions

    func setMode(_ newMode: Mode) {
        guard newMode != mode else { return }
        mode = newMode
        failure = nil
        hasAttempted = false
    }

    func toggleMode() { setMode(mode.toggled) }

    func submit() async {
        hasAttempted = true

        guard AuthService.normalizedEmail(email) != nil else {
            failure = .invalidEmail
            return
        }
        if mode == .signUp, !AuthService.isAcceptablePassword(password) {
            failure = .weakPassword
            return
        }

        failure = nil
        phase = .submitting

        do {
            switch mode {
            case .signUp:
                let outcome = try await auth.signUp(email: email, password: password)
                switch outcome {
                case .signedIn:
                    // `AppSession` is watching the auth state and moves the flow
                    // on; this screen has nothing left to do.
                    phase = .editing
                case .needsEmailConfirmation(let address):
                    password = ""
                    phase = .awaitingConfirmation(email: address)
                }

            case .signIn:
                try await auth.signIn(email: email, password: password)
                phase = .editing
            }
        } catch let failure as AuthFailure {
            apply(failure)
        } catch {
            apply(.unknown(error.localizedDescription))
        }
    }

    private func apply(_ failure: AuthFailure) {
        self.failure = failure
        phase = .editing
        // An account that already exists is not really an error — it is the
        // wrong mode. Put them where they meant to be, with the address kept and
        // the password dropped, since it was one for an account they do not have.
        if failure == .emailAlreadyRegistered {
            mode = .signIn
            password = ""
        }
    }

    /// Back to the fields from the confirmation hold, keeping the address so a
    /// typo is a quick fix.
    func editEmail() {
        failure = nil
        hasAttempted = false
        phase = .editing
    }

    func clearFailure() { failure = nil }

    /// Test seam for the branches that only a server can trigger. Nothing in the
    /// app calls this; `submit()` routes through the same code.
    func applyFailureForTesting(_ failure: AuthFailure) async {
        apply(failure)
    }
}
