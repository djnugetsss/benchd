import Foundation
import Supabase

enum SleeperAccountError: Error, Equatable, Sendable {
    case notConfigured
    case notSignedIn
    /// This profile has already connected that Sleeper account.
    case alreadyConnected
    case network
    case unknown(String)

    var message: String {
        switch self {
        case .notConfigured:
            "The app isn't connected to its backend yet."
        case .notSignedIn:
            "You need to sign in first."
        case .alreadyConnected:
            "That Sleeper account is already connected to your profile."
        case .network:
            "You're offline. Reconnect and try again."
        case .unknown:
            "We couldn't save that account. Try again."
        }
    }
}

/// Reads and writes the caller's own `sleeper_accounts` rows.
///
/// Every query here is scoped by RLS to the signed-in profile, so no filter on
/// `profile_id` is strictly required — they are included anyway, because a
/// query that is only correct because of a policy is a query that breaks
/// silently if the policy ever changes.
struct SleeperAccountService: Sendable {
    private let client: SupabaseClient?

    init(client: SupabaseClient? = SupabaseClientProvider.shared) {
        self.client = client
    }

    private struct NewAccount: Encodable {
        let profileID: UUID
        let sleeperUserID: String
        let username: String?
        let displayName: String?
        let avatar: String?

        enum CodingKeys: String, CodingKey {
            case profileID = "profile_id"
            case sleeperUserID = "sleeper_user_id"
            case username
            case displayName = "display_name"
            case avatar
        }
    }

    /// All Sleeper accounts connected to the given profile.
    func accounts(for profileID: UUID) async throws -> [SleeperAccount] {
        guard let client else { throw SleeperAccountError.notConfigured }
        do {
            return try await client
                .from("sleeper_accounts")
                .select()
                .eq("profile_id", value: profileID)
                .order("created_at", ascending: true)
                .execute()
                .value
        } catch {
            throw Self.translate(error)
        }
    }

    func hasConnectedAccount(profileID: UUID) async throws -> Bool {
        try await !accounts(for: profileID).isEmpty
    }

    /// Persists a confirmed Sleeper user.
    ///
    /// The database enforces `unique (profile_id, sleeper_user_id)`, so a
    /// duplicate is caught by Postgres rather than by a read-then-write check
    /// that would race.
    @discardableResult
    func connect(_ user: SleeperUser, to profileID: UUID) async throws -> SleeperAccount {
        guard let client else { throw SleeperAccountError.notConfigured }

        let payload = NewAccount(
            profileID: profileID,
            sleeperUserID: user.userID,
            username: user.username,
            displayName: user.displayName,
            avatar: user.avatar
        )

        do {
            return try await client
                .from("sleeper_accounts")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value
        } catch {
            throw Self.translate(error)
        }
    }

    static func translate(_ error: any Error) -> SleeperAccountError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return .network
            default:
                return .unknown(urlError.localizedDescription)
            }
        }

        // Postgres 23505 = unique_violation, which here can only be the
        // (profile_id, sleeper_user_id) constraint.
        if let postgrestError = error as? PostgrestError, postgrestError.code == "23505" {
            return .alreadyConnected
        }

        return .unknown(error.localizedDescription)
    }
}
