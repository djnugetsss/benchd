import Foundation
import Testing
@testable import Benchd

private struct StubLookup: SleeperUserLookup {
    let result: Result<SleeperUser, SleeperError>
    func user(username: String) async throws -> SleeperUser { try result.get() }
}

private let sampleUser = SleeperUser(
    userID: "12345", username: "anshm", displayName: "Ansh", avatar: nil
)

@MainActor
struct ConnectSleeperViewModelTests {

    private func model(_ result: Result<SleeperUser, SleeperError>) -> ConnectSleeperViewModel {
        ConnectSleeperViewModel(profileID: UUID(), lookup: StubLookup(result: result))
    }

    @Test("A successful lookup moves to confirmation rather than saving straight away")
    func lookupConfirms() async {
        let viewModel = model(.success(sampleUser))
        viewModel.username = "anshm"
        await viewModel.search()
        #expect(viewModel.phase == .confirming(sampleUser))
        #expect(viewModel.errorMessage == nil)
    }

    @Test("A missing user returns to the field with a message naming the input")
    func notFound() async {
        let viewModel = model(.failure(.userNotFound))
        viewModel.username = "nobody"
        await viewModel.search()
        #expect(viewModel.phase == .entry)
        #expect(viewModel.fieldHasError)
        #expect(viewModel.errorMessage?.contains("nobody") == true)
    }

    @Test("Network and outage failures read differently from a missing user")
    func failureMessagesDiffer() {
        let notFound = ConnectSleeperViewModel.message(for: .userNotFound, username: "x")
        let offline = ConnectSleeperViewModel.message(for: .network, username: "x")
        let outage = ConnectSleeperViewModel.message(for: .serviceUnavailable, username: "x")
        #expect(notFound != offline)
        #expect(offline != outage)
        #expect(offline.localizedCaseInsensitiveContains("offline"))
    }

    @Test("'Not me' returns to the field with the text intact")
    func rejectKeepsInput() async {
        let viewModel = model(.success(sampleUser))
        viewModel.username = "anshm"
        await viewModel.search()
        viewModel.reject()
        #expect(viewModel.phase == .entry)
        #expect(viewModel.username == "anshm")
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Search is blocked until there is a usable username")
    func canSearchGate() {
        let viewModel = model(.success(sampleUser))
        #expect(!viewModel.canSearch)
        viewModel.username = "   "
        #expect(!viewModel.canSearch)
        viewModel.username = "@anshm"
        #expect(viewModel.canSearch)
    }
}

@MainActor
struct SignInViewModelTests {

    private func model(
        mode: SignInViewModel.Mode = .signUp,
        email: String = "",
        password: String = ""
    ) -> SignInViewModel {
        SignInViewModel(
            auth: AuthService(client: nil), mode: mode, email: email, password: password
        )
    }

    @Test("Onboarding opens on creating an account, and can switch to signing in")
    func defaultMode() {
        let viewModel = model()
        #expect(viewModel.mode == .signUp)

        viewModel.toggleMode()
        #expect(viewModel.mode == .signIn)
        #expect(viewModel.mode.action == "Sign in")
    }

    @Test("Switching mode keeps what was typed and drops the stale error")
    func switchingModeKeepsInput() {
        let viewModel = SignInViewModel(
            auth: AuthService(client: nil),
            mode: .signUp,
            email: "ansh@example.com",
            password: "longenough",
            failure: .weakPassword
        )

        viewModel.toggleMode()
        #expect(viewModel.email == "ansh@example.com")
        #expect(viewModel.password == "longenough")
        #expect(viewModel.failure == nil)
    }

    @Test("Creating an account needs a real address and a long enough password")
    func signUpSubmitGate() {
        let viewModel = model()
        #expect(!viewModel.canSubmit)

        viewModel.email = "ansh@example.com"
        #expect(!viewModel.canSubmit)

        viewModel.password = "short"
        #expect(!viewModel.canSubmit)

        viewModel.password = "longenoughpassword"
        #expect(viewModel.canSubmit)
    }

    @Test("Signing in does not apply the length rule to an existing password")
    func signInSubmitGate() {
        // An account made before the app's floor existed still has to be usable.
        let viewModel = model(mode: .signIn, email: "ansh@example.com", password: "old")
        #expect(viewModel.canSubmit)
        #expect(!viewModel.passwordHasError)
    }

    @Test("The password rule is stated up front, and only while signing up")
    func passwordRequirementIsShownBeforehand() {
        let signUp = model()
        #expect(signUp.passwordRequirement?.contains("8") == true)

        // Nothing to state when the password already exists.
        #expect(model(mode: .signIn).passwordRequirement == nil)
    }

    @Test("A short password is flagged as it is typed, not after submitting")
    func passwordErrorIsLive() {
        let viewModel = model()
        #expect(!viewModel.passwordHasError)

        viewModel.password = "abc"
        #expect(viewModel.passwordHasError)

        viewModel.password = "abcdefghij"
        #expect(!viewModel.passwordHasError)
    }

    @Test("A half-typed address is not an error until something is submitted")
    func emailErrorWaitsForAnAttempt() async {
        let viewModel = model(email: "ans")
        #expect(!viewModel.emailHasError)

        await viewModel.submit()
        #expect(viewModel.emailHasError)
        #expect(viewModel.failure == .invalidEmail)
    }

    @Test("Submitting a short password reports the rule rather than calling out")
    func weakPasswordIsCaughtLocally() async {
        let viewModel = model(email: "ansh@example.com", password: "short")
        await viewModel.submit()

        #expect(viewModel.failure == .weakPassword)
        #expect(viewModel.phase == .editing)
    }

    @Test("An address that already has an account moves them to signing in")
    func alreadyRegisteredSwitchesMode() async {
        // Not really an error — the wrong mode. The address is kept, the
        // password is not, because it was a password for an account they do not
        // have yet.
        let viewModel = model(email: "ansh@example.com", password: "longenoughpassword")
        await viewModel.applyFailureForTesting(.emailAlreadyRegistered)

        #expect(viewModel.mode == .signIn)
        #expect(viewModel.email == "ansh@example.com")
        #expect(viewModel.password.isEmpty)
        #expect(viewModel.failure == .emailAlreadyRegistered)
    }

    @Test("Leaving the confirmation hold returns to the fields with the address")
    func leavingConfirmation() {
        let viewModel = SignInViewModel(
            auth: AuthService(client: nil),
            phase: .awaitingConfirmation(email: "ansh@example.com"),
            email: "ansh@example.com"
        )

        viewModel.setMode(.signIn)
        viewModel.editEmail()

        #expect(viewModel.phase == .editing)
        #expect(viewModel.mode == .signIn)
        #expect(viewModel.email == "ansh@example.com")
    }
}

struct EmailNormalizationTests {

    @Test("Plausible addresses are accepted and normalized")
    func accepts() {
        #expect(AuthService.normalizedEmail("  Ansh@Example.COM ") == "ansh@example.com")
        #expect(AuthService.normalizedEmail("a.b+tag@sub.example.co.uk") == "a.b+tag@sub.example.co.uk")
    }

    @Test("Clearly broken addresses are rejected")
    func rejects() {
        #expect(AuthService.normalizedEmail("") == nil)
        #expect(AuthService.normalizedEmail("nope") == nil)
        #expect(AuthService.normalizedEmail("@example.com") == nil)
        #expect(AuthService.normalizedEmail("a@b") == nil)
        #expect(AuthService.normalizedEmail("a@b.c") == nil)
        #expect(AuthService.normalizedEmail("two words@example.com") == nil)
        #expect(AuthService.normalizedEmail("a@@example.com") == nil)
    }
}

struct PasswordRuleTests {

    @Test("Length is the only rule, and it is the stated one")
    func length() {
        #expect(!AuthService.isAcceptablePassword(""))
        #expect(!AuthService.isAcceptablePassword(String(repeating: "a", count: 7)))
        #expect(AuthService.isAcceptablePassword(String(repeating: "a", count: 8)))
        #expect(AuthService.minimumPasswordLength == 8)
    }

    @Test("A passphrase is not rejected for lacking punctuation")
    func noCharacterClassRules() {
        // Character-class rules push people towards Password1! and are worse
        // than length. Nothing here should object to four honest words.
        #expect(AuthService.isAcceptablePassword("correct horse battery staple"))
    }
}

struct AuthFailureTests {

    @Test("Every failure has something to say")
    func messages() {
        let all: [AuthFailure] = [
            .notConfigured, .invalidEmail, .weakPassword, .emailAlreadyRegistered,
            .invalidCredentials, .emailNotConfirmed, .network, .rateLimited, .unknown("x"),
        ]
        for failure in all {
            #expect(!failure.message.isEmpty)
        }
    }

    @Test("A failed sign-in never says which half was wrong")
    func credentialsAreNotEnumerable() {
        // Saying "no account with that email" hands anyone with a list of
        // addresses a way to find out which ones are real.
        let message = AuthFailure.invalidCredentials.message.lowercased()
        #expect(!message.contains("password is"))
        #expect(!message.contains("no account"))
        #expect(!message.contains("not found"))
    }

    @Test("The weak-password message quotes the rule the screen states")
    func weakPasswordQuotesTheRule() {
        #expect(AuthFailure.weakPassword.message.contains("\(AuthService.minimumPasswordLength)"))
    }

    @Test("Failures about the address are marked as such")
    func fieldAttribution() {
        #expect(AuthFailure.invalidEmail.isAboutEmail)
        #expect(AuthFailure.emailAlreadyRegistered.isAboutEmail)
        #expect(AuthFailure.emailNotConfirmed.isAboutEmail)
        #expect(!AuthFailure.invalidCredentials.isAboutEmail)
        #expect(!AuthFailure.weakPassword.isAboutEmail)
    }

    @Test("Offline reads as offline rather than as an unknown error")
    func network() {
        #expect(AuthService.translate(URLError(.timedOut)) == .network)
        #expect(AuthService.translate(URLError(.notConnectedToInternet)) == .network)
        #expect(AuthService.translate(URLError(.networkConnectionLost)) == .network)
    }
}
