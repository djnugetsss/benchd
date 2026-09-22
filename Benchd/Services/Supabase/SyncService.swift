import Foundation
import Supabase

enum SyncError: Error, Equatable, Sendable {
    case notConfigured
    case network
    case failed(String)

    var message: String {
        switch self {
        case .notConfigured: "The app isn't connected to its backend yet."
        case .network: "You're offline. We'll pick this up when you reconnect."
        case .failed(let reason): reason
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
