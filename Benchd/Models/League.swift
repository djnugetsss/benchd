import Foundation

/// A Sleeper league. Keyed on Sleeper's own `league_id`.
struct League: Codable, Hashable, Sendable, Identifiable {
    let leagueID: String
    let name: String
    let season: Int
    let totalRosters: Int?
    /// Sleeper's flat scoring table: scoring key -> points. Genuinely all
    /// numbers, so this is typed rather than freeform JSON.
    let scoringSettings: [String: Double]
    let rosterPositions: [String]?
    /// The prior season of the same league. May point at a league that has never
    /// been synced — there is no foreign key behind it.
    let previousLeagueID: String?
    /// Sleeper value: `pre_draft`, `drafting`, `in_season`, `complete`. Left as a
    /// string because Sleeper owns this vocabulary and can extend it.
    let status: String?
    let avatar: String?
    /// Mixed types in practice, so freeform.
    let settings: [String: JSONValue]

    var id: String { leagueID }

    enum CodingKeys: String, CodingKey {
        case leagueID = "league_id"
        case name
        case season
        case totalRosters = "total_rosters"
        case scoringSettings = "scoring_settings"
        case rosterPositions = "roster_positions"
        case previousLeagueID = "previous_league_id"
        case status
        case avatar
        case settings
    }
}

/// One roster within a league.
///
/// `sleeperUserID` is a raw Sleeper id, not a Benchd user — most league members
/// will never have an account here.
struct LeagueMember: Codable, Hashable, Sendable, Identifiable {
    let leagueID: String
    let rosterID: Int
    /// `nil` for an orphaned roster (a team with no manager).
    let sleeperUserID: String?
    let teamName: String?
    let coOwnerIDs: [String]?
    let wins: Int
    let losses: Int
    let ties: Int
    let fpts: Double
    let fptsAgainst: Double

    /// Composite key, flattened for SwiftUI.
    var id: String { "\(leagueID)-\(rosterID)" }

    enum CodingKeys: String, CodingKey {
        case leagueID = "league_id"
        case rosterID = "roster_id"
        case sleeperUserID = "sleeper_user_id"
        case teamName = "team_name"
        case coOwnerIDs = "co_owner_ids"
        case wins, losses, ties, fpts
        case fptsAgainst = "fpts_against"
    }
}
