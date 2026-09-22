import Foundation

/// The precomputed career profile for one connected Sleeper account.
///
/// A derived cache: every value is recomputable from league members, matchups,
/// and draft picks. Written only by the edge function that computes it.
struct CareerStats: Codable, Hashable, Sendable, Identifiable {
    let sleeperAccountID: UUID
    let wins: Int
    let losses: Int
    let ties: Int
    let championships: Int
    let seasons: Int
    let leaguesCount: Int
    let pointsFor: Double
    let pointsAgainst: Double
    /// Best and worst draft picks, rivalries, streaks, per-season breakdowns.
    /// Freeform so the wrap cards can grow new derived stats without a migration.
    let details: JSONValue
    let computedAt: Date

    var id: UUID { sleeperAccountID }

    /// Games that produced a result. Ties count.
    var gamesPlayed: Int { wins + losses + ties }

    /// A tie counts as half a win, the standard fantasy convention.
    /// `nil` rather than zero when nothing has been played — a brand-new account
    /// has no win rate, and showing "0%" would be a lie.
    var winPercentage: Double? {
        guard gamesPlayed > 0 else { return nil }
        return (Double(wins) + Double(ties) / 2) / Double(gamesPlayed)
    }

    /// "128–74" or "128–74–2".
    var recordText: String {
        ties > 0 ? "\(wins)–\(losses)–\(ties)" : "\(wins)–\(losses)"
    }

    enum CodingKeys: String, CodingKey {
        case sleeperAccountID = "sleeper_account_id"
        case wins, losses, ties, championships, seasons
        case leaguesCount = "leagues_count"
        case pointsFor = "points_for"
        case pointsAgainst = "points_against"
        case details
        case computedAt = "computed_at"
    }
}
