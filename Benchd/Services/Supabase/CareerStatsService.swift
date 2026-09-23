import Foundation
import Supabase

/// Reads the precomputed career profile.
///
/// The row is written by the `sync-sleeper` edge function and readable only by
/// the owner of the underlying Sleeper account, via RLS.
struct CareerStatsService: Sendable {
    private let client: SupabaseClient?

    init(client: SupabaseClient? = SupabaseClientProvider.shared) {
        self.client = client
    }

    /// The career stats for an account, or `nil` when the sync has not produced
    /// them yet.
    ///
    /// `nil` is a normal answer, not an error: a freshly connected account has
    /// no row until its first sync finishes.
    func stats(for accountID: UUID) async throws -> CareerStats? {
        guard let client else { throw CareerStatsError.notConfigured }

        do {
            let rows: [CareerStats] = try await client
                .from("career_stats")
                .select()
                .eq("sleeper_account_id", value: accountID)
                .limit(1)
                .execute()
                .value
            let stats = rows.first

            AppLog.profile.debug(
                "career_stats fetch for \(accountID.uuidString, privacy: .public): \(stats == nil ? "no row" : "ok", privacy: .public)"
            )
            return stats
        } catch {
            // Logged, then rethrown. Swallowing here is what turns "the screen
            // is stuck on skeletons" into an unfindable bug.
            AppLog.profile.error(
                "career_stats fetch failed: \(String(describing: error), privacy: .public)"
            )
            throw CareerStatsError.translate(error)
        }
    }
}

enum CareerStatsError: Error, Equatable, Sendable {
    case notConfigured
    case network
    case failed(String)

    var message: String {
        switch self {
        case .notConfigured: "The app isn't connected to its backend yet."
        case .network: "You're offline. Pull to refresh once you reconnect."
        case .failed: "We couldn't load your career just now."
        }
    }

    static func translate(_ error: any Error) -> CareerStatsError {
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
