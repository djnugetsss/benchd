import Foundation

/// Drives the Sleeper connection step.
///
/// Sleeper has no OAuth, so there is no way to *prove* an account belongs to the
/// person typing. The flow compensates with an explicit confirmation: look the
/// username up, show the avatar and display name back, and only save once they
/// say it's them.
@Observable
final class ConnectSleeperViewModel {

    enum Phase: Equatable {
        case entry
        case searching
        /// Found someone; waiting on "That's me".
        case confirming(SleeperUser)
        case saving(SleeperUser)
    }

    var username: String = ""
    private(set) var phase: Phase = .entry
    private(set) var errorMessage: String?
    /// Set when the lookup itself failed, so the field can show its error state.
    private(set) var fieldHasError = false

    private let lookup: any SleeperUserLookup
    private let accounts: SleeperAccountService
    private let profileID: UUID
    private let onConnected: (SleeperAccount) -> Void

    init(
        profileID: UUID,
        lookup: any SleeperUserLookup = SleeperClient(),
        accounts: SleeperAccountService = SleeperAccountService(),
        onConnected: @escaping (SleeperAccount) -> Void = { _ in }
    ) {
        self.profileID = profileID
        self.lookup = lookup
        self.accounts = accounts
        self.onConnected = onConnected
    }

    var canSearch: Bool {
        phase == .entry && SleeperClient.sanitize(username) != nil
    }

    var isBusy: Bool {
        if case .searching = phase { return true }
        if case .saving = phase { return true }
        return false
    }

    func search() async {
        guard canSearch else { return }
        errorMessage = nil
        fieldHasError = false
        phase = .searching

        do {
            let user = try await lookup.user(username: username)
            phase = .confirming(user)
        } catch let error as SleeperError {
            fieldHasError = true
            errorMessage = Self.message(for: error, username: username)
            phase = .entry
        } catch {
            fieldHasError = true
            errorMessage = "Something went wrong looking that up. Try again."
            phase = .entry
        }
    }

    func confirm() async {
        guard case .confirming(let user) = phase else { return }
        errorMessage = nil
        phase = .saving(user)

        do {
            let account = try await accounts.connect(user, to: profileID)
            onConnected(account)
        } catch let error as SleeperAccountError {
            errorMessage = error.message
            // An already-connected account is not worth re-confirming — send
            // them back to the field rather than leaving a dead "That's me".
            phase = error == .alreadyConnected ? .entry : .confirming(user)
        } catch {
            errorMessage = "We couldn't save that account. Try again."
            phase = .confirming(user)
        }
    }

    /// "Not me" — back to the field with the text intact so it can be corrected.
    func reject() {
        errorMessage = nil
        fieldHasError = false
        phase = .entry
    }

    func clearError() {
        errorMessage = nil
        fieldHasError = false
    }

    static func message(for error: SleeperError, username: String) -> String {
        let trimmed = SleeperClient.sanitize(username) ?? username
        return switch error {
        case .userNotFound:
            "No Sleeper account called \"\(trimmed)\". Check the spelling — it's your username, not your display name."
        case .invalidUsername:
            "Enter your Sleeper username."
        case .network:
            "You're offline. Reconnect and try again."
        case .serviceUnavailable:
            "Sleeper isn't responding right now. Try again in a moment."
        case .unexpectedResponse:
            "Sleeper sent something we couldn't read. Try again in a moment."
        }
    }
}
