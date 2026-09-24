import Foundation
import Supabase

/// Reads the weekly wrap.
///
/// Both calls are Postgres functions rather than table reads — a wrap is a join
/// across matchups, league members and players with a ranking on top, and doing
/// that in the app would mean shipping a week of every roster's lineup to the
/// phone to throw almost all of it away.
///
/// Both functions are `security invoker`, so a caller only ever sees weeks
/// belonging to a Sleeper account they own.
struct WrapService: Sendable {
    private let client: SupabaseClient?

    init(client: SupabaseClient? = SupabaseClientProvider.shared) {
        self.client = client
    }

    /// One week, or `nil` when it has not been played.
    ///
    /// `nil` is a normal answer, not an error: Sleeper answers for every week of
    /// a live season, including the ones that have not happened.
    func wrap(for accountID: UUID, season: Int, week: Int) async throws -> WeeklyWrap? {
        guard let client else { throw WrapError.notConfigured }

        do {
            let response = try await client
                .rpc("weekly_wrap", params: WeekRequest(
                    p_sleeper_account_id: accountID, p_season: season, p_week: week
                ))
                .execute()

            guard let data = Self.nonNull(response.data) else {
                AppLog.wraps.debug("weekly_wrap \(season, privacy: .public)w\(week, privacy: .public): not played")
                return nil
            }
            return try PostgrestCoding.decoder.decode(WeeklyWrap.self, from: data)
        } catch {
            AppLog.wraps.error("weekly_wrap failed: \(String(describing: error), privacy: .public)")
            throw WrapError.translate(error)
        }
    }

    /// The most recently played weeks, newest first.
    ///
    /// Whole wraps rather than a summary, because the history strip renders real
    /// cards as its thumbnails — a list of weeks would need a second round trip
    /// each time someone scrolled.
    func recentWraps(for accountID: UUID, limit: Int = 8) async throws -> [WeeklyWrap] {
        guard let client else { throw WrapError.notConfigured }

        do {
            let response = try await client
                .rpc("recent_weekly_wraps", params: RecentRequest(
                    p_sleeper_account_id: accountID, p_limit: limit
                ))
                .execute()

            guard let data = Self.nonNull(response.data) else { return [] }
            let wraps = try PostgrestCoding.decoder.decode([WeeklyWrap].self, from: data)

            AppLog.wraps.debug("recent_weekly_wraps: \(wraps.count, privacy: .public) weeks")
            return wraps
        } catch {
            AppLog.wraps.error("recent_weekly_wraps failed: \(String(describing: error), privacy: .public)")
            throw WrapError.translate(error)
        }
    }

    /// The body, unless the function returned SQL null.
    ///
    /// PostgREST hands back a literal `null` for a function that returned
    /// nothing. Decoding that as a wrap throws, and a thrown error here would be
    /// indistinguishable from a real failure — so it is recognised by hand.
    static func nonNull(_ data: Data) -> Data? {
        let trimmed = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.isEmpty || trimmed == "null") ? nil : data
    }

    private struct WeekRequest: Encodable, Sendable {
        let p_sleeper_account_id: UUID
        let p_season: Int
        let p_week: Int
    }

    private struct RecentRequest: Encodable, Sendable {
        let p_sleeper_account_id: UUID
        let p_limit: Int
    }
}

enum WrapError: Error, Equatable, Sendable {
    case notConfigured
    case network
    case failed(String)

    var message: String {
        switch self {
        case .notConfigured: "The app isn't connected to its backend yet."
        case .network: "You're offline. Pull to refresh once you reconnect."
        case .failed: "We couldn't build your wrap just now."
        }
    }

    static func translate(_ error: any Error) -> WrapError {
        if let wrapError = error as? WrapError { return wrapError }
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
