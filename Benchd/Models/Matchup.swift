import Foundation

/// One roster's result for one week. The raw material for the weekly wrap cards.
struct Matchup: Codable, Hashable, Sendable, Identifiable {
    let leagueID: String
    let week: Int
    let rosterID: Int
    /// Shared by the two sides of a head-to-head. `nil` on a bye.
    let matchupID: Int?
    let points: Double?
    /// Sleeper player ids in the starting lineup, in slot order.
    let starters: [String]?
    /// The full roster that week. Needed for bench points — `starters` alone
    /// cannot tell you what was left on the bench.
    let players: [String]?
    /// Sleeper player id -> points scored that week.
    let playersPoints: [String: Double]
    let customPoints: Double?

    var id: String { "\(leagueID)-\(week)-\(rosterID)" }

    /// Points from players who were on the roster but not started.
    var benchPoints: Double {
        let startersSet = Set(starters ?? [])
        return playersPoints
            .filter { !startersSet.contains($0.key) }
            .values
            .reduce(0, +)
    }

    enum CodingKeys: String, CodingKey {
        case leagueID = "league_id"
        case week
        case rosterID = "roster_id"
        case matchupID = "matchup_id"
        case points
        case starters
        case players
        case playersPoints = "players_points"
        case customPoints = "custom_points"
    }
}
