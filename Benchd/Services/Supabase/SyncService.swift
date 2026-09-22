import Foundation
import Supabase

enum SyncError: Error, Equatable, Sendable {
    case notConfigured
    /// The edge function is not deployed to this project (HTTP 404).
    case notDeployed
    /// The project rejected our credentials (HTTP 401/403).
    case unauthorized
    case network
    case failed(String)

    var message: String {
        switch self {
        case .notConfigured:
            "The app isn't connected to its backend yet."
        case .notDeployed:
            "The sync service isn't available yet. This is a setup problem, not something you did."
        case .unauthorized:
            "We weren't allowed to start the sync. Check the app's Supabase keys."
        case .network:
            "You're offline. We'll pick this up when you reconnect."
        case .failed(let reason):
            reason
        }
    }

    /// `true` when retrying or waiting cannot possibly help.
    ///
    /// This distinction is the whole point of the enum. A request we never got
    /// an answer to may well be a sync running happily server-side, so the
    /// screen should keep watching. A request the server *answered* with "no
    /// such function" will never produce a sync, and waiting on it just burns
    /// the stall timeout in front of the person.
    var isPermanent: Bool {
        switch self {
        case .notConfigured, .notDeployed, .unauthorized: true
        case .network, .failed: false
        }
    }
}

/// Starts a Sleeper sync and reads its progress.
///
/// Progress is polled, not streamed. This is a periodic-sync app by design, and
/// a Realtime subscription for a one-minute first run would add a websocket,
/// a reconnection story, and a second source of truth for no benefit.
struct SyncService: Sendable {
    private let client: SupabaseClient?

    init(client: SupabaseClient? = SupabaseClientProvider.shared) {
        self.client = client
    }

    private struct SyncRequest: Encodable {
        let sleeperAccountID: UUID
        let trigger: String

        enum CodingKeys: String, CodingKey {
            case sleeperAccountID = "sleeper_account_id"
            case trigger
        }
    }

    /// Kicks off a sync.
    ///
    /// The edge function runs for far longer than this call waits — it returns
    /// once the work is accepted, and the caller watches `events(for:after:)`
    /// from there. A timeout here is not a failed sync.
    func start(accountID: UUID) async throws {
        guard let client else { throw SyncError.notConfigured }
        do {
            try await client.functions.invoke(
                "sync-sleeper",
                options: FunctionInvokeOptions(
                    body: SyncRequest(sleeperAccountID: accountID, trigger: "app")
                )
            )
        } catch {
            throw Self.translate(error)
        }
    }

    /// Events newer than `after`, oldest first. Pass `0` for the whole feed.
    func events(for accountID: UUID, after id: Int) async throws -> [SyncEvent] {
        guard let client else { throw SyncError.notConfigured }
        do {
            return try await client
                .from("sync_events")
                .select()
                .eq("sleeper_account_id", value: accountID)
                .gt("id", value: id)
                .order("id", ascending: true)
                .execute()
                .value
        } catch {
            throw Self.translate(error)
        }
    }

    static func translate(_ error: any Error) -> SyncError {
        if let functionsError = error as? FunctionsError {
            switch functionsError {
            case .httpError(let code, _):
                switch code {
                case 404: return .notDeployed
                case 401, 403: return .unauthorized
                default: return .failed("The sync service returned \(code).")
                }
            case .relayError:
                // The gateway could not reach the function. Transient.
                return .network
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return .network
            default:
                return .failed(urlError.localizedDescription)
            }
        }
        return .failed(error.localizedDescription)
    }
}
