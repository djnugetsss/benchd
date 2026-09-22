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

    @Test("Submission is gated on a plausible address")
    func submitGate() {
        let viewModel = SignInViewModel(auth: AuthService(client: nil))
        #expect(!viewModel.canSubmit)
        viewModel.email = "nope"
        #expect(!viewModel.canSubmit)
        viewModel.email = "ansh@example.com"
        #expect(viewModel.canSubmit)
    }

    @Test("Editing the email returns to the form without losing it")
    func editEmailKeepsInput() {
        let viewModel = SignInViewModel(
            auth: AuthService(client: nil),
            phase: .sent(email: "ansh@example.com"),
            email: "ansh@example.com"
        )
        viewModel.editEmail()
        #expect(viewModel.phase == .editing)
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
