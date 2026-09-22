import Foundation

/// An NFL player. Backs player pages and resolves the ids stored in matchups,
/// draft picks, and news.
struct Player: Codable, Hashable, Sendable, Identifiable {
    let playerID: String
    let fullName: String?
    let firstName: String?
    let lastName: String?
    let position: String?
    let fantasyPositions: [String]?
    let team: String?
    /// Sleeper roster status: `Active`, `Inactive`, `Injured Reserve`, …
    let status: String?
    let number: Int?
    let age: Int?
    let yearsExp: Int?

    /// Sleeper value: `Questionable`, `Doubtful`, `Out`, `IR`, or `nil`.
    let injuryStatus: String?
    let injuryBodyPart: String?
    let injuryNotes: String?
    /// A Postgres `date`, not a timestamp — see `CalendarDate`.
    let injuryStartDate: CalendarDate?

    /// Generated in Postgres: lowercased with punctuation stripped, so
    /// "A.J. Brown" becomes "ajbrown". Read-only.
    let searchName: String?

    var id: String { playerID }

    /// `true` when Sleeper is reporting anything at all about the player's health.
    var isInjured: Bool {
        guard let injuryStatus else { return false }
        return !injuryStatus.isEmpty
    }

    /// Normalizes a user's query the same way Postgres normalizes `search_name`,
    /// so client-side filtering and server-side search agree.
    ///
    /// Must stay equivalent to the generated column's
    /// `lower(regexp_replace(full_name, '[^a-zA-Z0-9]+', '', 'g'))`. That means
    /// ASCII only: `Character.isLetter` would keep "é", which the Postgres
    /// character class strips, and the two sides would silently diverge.
    static func normalizeForSearch(_ query: String) -> String {
        query.lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    enum CodingKeys: String, CodingKey {
        case playerID = "player_id"
        case fullName = "full_name"
        case firstName = "first_name"
        case lastName = "last_name"
        case position
        case fantasyPositions = "fantasy_positions"
        case team, status, number, age
        case yearsExp = "years_exp"
        case injuryStatus = "injury_status"
        case injuryBodyPart = "injury_body_part"
        case injuryNotes = "injury_notes"
        case injuryStartDate = "injury_start_date"
        case searchName = "search_name"
    }
}
