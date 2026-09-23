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
    /// Streaks, the season timeline, draft grades, rivalries, and the featured
    /// facts. A `jsonb` column so the server can grow new derived stats without a
    /// migration — see `CareerDetails` for how that shapes the decoding.
    let details: CareerDetails
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
    var recordText: String { Record.text(wins: wins, losses: losses, ties: ties) }

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

extension CareerStats {
    /// Decoded by hand for one reason: `details` must never be able to fail the
    /// row.
    ///
    /// The headline columns are what the profile is mostly made of, and they are
    /// strict — a missing `wins` is a real problem and should throw. The details
    /// payload is a server-computed cache whose shape may run ahead of this build,
    /// so an unreadable one degrades to `CareerDetails.empty` and the screen falls
    /// back to those headline numbers. Losing a section beats losing the career.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sleeperAccountID = try container.decode(UUID.self, forKey: .sleeperAccountID)
        wins = try container.decode(Int.self, forKey: .wins)
        losses = try container.decode(Int.self, forKey: .losses)
        ties = try container.decode(Int.self, forKey: .ties)
        championships = try container.decode(Int.self, forKey: .championships)
        seasons = try container.decode(Int.self, forKey: .seasons)
        leaguesCount = try container.decode(Int.self, forKey: .leaguesCount)
        pointsFor = try container.decode(Double.self, forKey: .pointsFor)
        pointsAgainst = try container.decode(Double.self, forKey: .pointsAgainst)
        computedAt = try container.decode(Date.self, forKey: .computedAt)
        details = (try? container.decode(CareerDetails.self, forKey: .details)) ?? .empty
    }
}
