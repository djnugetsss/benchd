import Foundation

/// One week of a manager's football, across every league they play in.
///
/// Computed on demand by the `weekly_wrap` Postgres function — see
/// `supabase/migrations/20260923100000_weekly_wrap.sql`, which is the authority
/// on how each number is derived. Not cached anywhere: a wrap reads a single week
/// of `matchups`, and a wrap that is a day stale is a wrap showing the wrong score.
///
/// This is the payload behind the shareable card, which means every value here
/// ends up on someone's Instagram story. Nothing in it may be approximately true.
struct WeeklyWrap: Codable, Hashable, Sendable, Identifiable {
    let season: Int
    let week: Int
    let record: WrapRecord
    /// Summed across leagues, as is `pointsAgainst`.
    let pointsFor: Double
    let pointsAgainst: Double
    /// One entry per league the manager played that week, highest score first.
    let leagues: [WrapLeagueResult]
    /// The best three starters of the week, already ranked.
    let performers: [WrapPerformer]
    /// The one thing worth saying out loud. Absent only when the week is bare.
    let highlight: WrapHighlight?

    var id: String { "\(season)-\(week)" }

    /// "1–1", or "1–1–1" when a week produced a tie.
    nonisolated var recordText: String {
        Record.text(wins: record.wins, losses: record.losses, ties: record.ties)
    }

    /// Someone in more than one league had more than one week.
    var isMultiLeague: Bool { leagues.count > 1 }

    /// "Week 5" — the card's masthead.
    var weekText: String { "Week \(week)" }

    /// What the big points number is counting. A single-league manager just
    /// scored; someone in three leagues scored across three of them, and the
    /// label has to say so or the number looks wrong.
    var pointsLabel: String {
        isMultiLeague ? "Points across \(leagues.count) leagues" : "Points"
    }

    /// "1–1 across two leagues" / "Won by 18.2 in Dynasty Dads".
    ///
    /// The line under the hero number: it has to carry the result without
    /// repeating whatever the highlight already says.
    var resultLine: String {
        guard let first = leagues.first else { return recordText }
        if isMultiLeague {
            return "\(recordText) across \(leagues.count) leagues"
        }
        switch first.result {
        case .win:  return "Beat \(first.opponentName ?? "your opponent")"
        case .loss: return "Lost to \(first.opponentName ?? "your opponent")"
        case .tie:  return "Tied \(first.opponentName ?? "your opponent")"
        case nil:   return first.leagueName
        }
    }

    enum CodingKeys: String, CodingKey {
        case season, week, record, leagues, performers, highlight
        case pointsFor = "points_for"
        case pointsAgainst = "points_against"
    }
}

// MARK: - Record

struct WrapRecord: Codable, Hashable, Sendable {
    let wins: Int
    let losses: Int
    let ties: Int

    /// A bye week, or a week whose matchups Sleeper has not paired yet.
    var isEmpty: Bool { wins + losses + ties == 0 }
}

// MARK: - Leagues

/// How one league went this week.
struct WrapLeagueResult: Codable, Hashable, Sendable, Identifiable {
    let leagueID: String
    let leagueName: String
    let teamName: String
    let points: Double
    /// Absent on a bye, and in the offseason weeks Sleeper still answers for.
    let opponentName: String?
    let opponentPoints: Double?
    let result: WrapResult?
    /// Positive when they won. `nil` when there was no opponent.
    let margin: Double?
    let leagueRank: Int?
    /// Rosters that have reported a score this week — not the league's size.
    let teams: Int?
    /// The week's top score, and only claimed once every roster has reported.
    let leagueHigh: Bool

    var id: String { leagueID }

    /// "148.6 – 130.4", the way a scoreline is written.
    var scoreline: String? {
        guard let opponentPoints else { return nil }
        return "\(points.wrapPoints) – \(opponentPoints.wrapPoints)"
    }

    enum CodingKeys: String, CodingKey {
        case points, margin, teams, result
        case leagueID = "league_id"
        case leagueName = "league_name"
        case teamName = "team_name"
        case opponentName = "opponent_name"
        case opponentPoints = "opponent_points"
        case leagueRank = "league_rank"
        case leagueHigh = "league_high"
    }
}

extension WrapLeagueResult {
    /// Hand-written for one field: `result`.
    ///
    /// A result Postgres has not sent before would otherwise throw and take the
    /// whole card down. A card missing one badge is recoverable; a card that
    /// refused to load on the day someone wanted to post it is not.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        leagueID = try container.decode(String.self, forKey: .leagueID)
        leagueName = try container.decode(String.self, forKey: .leagueName)
        teamName = try container.decode(String.self, forKey: .teamName)
        points = try container.decode(Double.self, forKey: .points)
        opponentName = try container.decodeIfPresent(String.self, forKey: .opponentName)
        opponentPoints = try container.decodeIfPresent(Double.self, forKey: .opponentPoints)
        margin = try container.decodeIfPresent(Double.self, forKey: .margin)
        leagueRank = try container.decodeIfPresent(Int.self, forKey: .leagueRank)
        teams = try container.decodeIfPresent(Int.self, forKey: .teams)
        leagueHigh = try container.decodeIfPresent(Bool.self, forKey: .leagueHigh) ?? false
        result = (try? container.decodeIfPresent(String.self, forKey: .result))
            .flatMap { $0 }
            .flatMap(WrapResult.init(rawValue:))
    }
}

/// Won, lost, or tied.
enum WrapResult: String, Codable, Sendable {
    case win = "W"
    case loss = "L"
    case tie = "T"

    var word: String {
        switch self {
        case .win: "Won"
        case .loss: "Lost"
        case .tie: "Tied"
        }
    }
}

// MARK: - Performers

/// A starter and what he did. Bench players are a different card.
struct WrapPerformer: Codable, Hashable, Sendable, Identifiable {
    let playerID: String
    let name: String
    let position: String?
    let team: String?
    let points: Double
    /// Which league this line came from — the same player can start in two and
    /// score differently under each one's scoring settings.
    let leagueName: String?

    var id: String { playerID }

    /// "WR · LAR", or whichever half of it Sleeper knows.
    var subtitle: String {
        [position, team].compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    enum CodingKeys: String, CodingKey {
        case name, position, team, points
        case playerID = "player_id"
        case leagueName = "league_name"
    }
}

// MARK: - Highlight

/// The one line the card leads with.
///
/// `headline` is written by the database so a new kind of highlight can ship
/// without an App Store release — the same reason the sync writes its own
/// progress copy. `kind` is carried so the app can style a story it recognises.
struct WrapHighlight: Codable, Hashable, Sendable {
    let kind: String
    /// A short complete phrase: "Won by 0.4", "Top score in the league".
    let headline: String
    let value: Double?
    /// Which league it happened in, when that is not obvious.
    let caption: String?

    /// The kinds this build knows by name. An unknown kind still renders from
    /// `headline` alone, which is the point of the server writing it.
    enum Kind {
        static let leagueHigh = "league_high"
        static let perfectWeek = "perfect_week"
        static let closeWin = "close_win"
        static let closeLoss = "close_loss"
        static let bigWin = "big_win"
        static let rank = "rank"
        static let points = "points"
    }

    /// Whether the value is a score rather than a count of games or a placing.
    /// Decides whether the number keeps a decimal.
    var valueIsPoints: Bool {
        switch kind {
        case Kind.perfectWeek, Kind.rank: false
        default: true
        }
    }
}

// MARK: - Formatting

extension Double {
    /// "148.6" — a fantasy score, always to one decimal. Scores are quoted to a
    /// tenth everywhere in fantasy football, and "148" reads as a different sport.
    var wrapPoints: String { formatted(.number.precision(.fractionLength(1))) }
}
