import Foundation

/// A league's draft.
struct Draft: Codable, Hashable, Sendable, Identifiable {
    let draftID: String
    let leagueID: String
    let season: Int
    /// Sleeper value: `snake`, `linear`, `auction`. Free text by design.
    let type: String?
    let status: String?
    let rounds: Int?
    let startTime: Date?
    let settings: [String: JSONValue]

    var id: String { draftID }

    enum CodingKeys: String, CodingKey {
        case draftID = "draft_id"
        case leagueID = "league_id"
        case season, type, status, rounds
        case startTime = "start_time"
        case settings
    }
}

/// A single pick. `pickNo` is Sleeper's overall pick number within the draft.
struct DraftPick: Codable, Hashable, Sendable, Identifiable {
    let draftID: String
    let pickNo: Int
    let round: Int
    let draftSlot: Int?
    /// Sleeper player id. Not a foreign key — the players table syncs on its own
    /// schedule, so this can reference a player that has not been pulled yet.
    /// Treat a lookup miss as "unknown player", never as an error.
    let playerID: String?
    let rosterID: Int?
    /// The Sleeper user id who made the pick.
    let pickedBy: String?
    let isKeeper: Bool
    /// Sleeper returns pick metadata as all-string values (first_name, team,
    /// position, …), so this is typed rather than freeform JSON.
    let metadata: [String: String]

    var id: String { "\(draftID)-\(pickNo)" }

    enum CodingKeys: String, CodingKey {
        case draftID = "draft_id"
        case pickNo = "pick_no"
        case round
        case draftSlot = "draft_slot"
        case playerID = "player_id"
        case rosterID = "roster_id"
        case pickedBy = "picked_by"
        case isKeeper = "is_keeper"
        case metadata
    }
}
