import Foundation

/// The typed shape of `career_stats.details`.
///
/// Computed by the `sync-sleeper` edge function — see
/// `supabase/functions/_shared/career.ts`, which is the authority on how every
/// number here is derived. The column is `jsonb` precisely so the server can grow
/// new derived stats without a migration, which means **this app may be older than
/// the payload it is handed**.
///
/// So every type in this file decodes leniently: a missing key falls back, a value
/// of the wrong type falls back, and an unknown key is ignored. A server-side shape
/// change costs one section of the profile, never the whole screen. `CareerStats`
/// applies the same rule one level up — an undecodable payload becomes
/// ``CareerDetails/empty`` rather than failing the row, so the headline numbers
/// survive regardless.
///
/// `version` is carried for the day a change is not backward compatible. It is
/// deliberately **not** gated on: refusing to render an unrecognised version would
/// blank the profile the moment the server moved ahead of the App Store.
struct CareerDetails: Codable, Hashable, Sendable {
    /// The payload's schema version, as written by the edge function. `0` means
    /// "no details": either a row computed before this existed, or one this build
    /// could not read.
    let version: Int
    /// All-time regular season. Agrees with the promoted columns on `career_stats`.
    let regularSeason: CareerRecord
    let playoffs: PlayoffRecord
    let streaks: CareerStreaks
    /// One row per league-season, oldest first.
    let seasons: [SeasonSummary]
    let bestSeason: SeasonSummary?
    let worstSeason: SeasonSummary?
    let draft: DraftGrades
    let rivalries: RivalrySummary
    /// The few numbers worth setting large on the profile.
    let facts: [CareerFact]

    /// No details to show. The profile falls back to its headline numbers.
    static let empty = CareerDetails(
        version: 0,
        regularSeason: .empty,
        playoffs: .empty,
        streaks: .empty,
        seasons: [],
        bestSeason: nil,
        worstSeason: nil,
        draft: .empty,
        rivalries: .empty,
        facts: []
    )

    /// True when there is nothing beyond the headline columns to render.
    var isEmpty: Bool {
        seasons.isEmpty && facts.isEmpty && streaks.isEmpty
            && draft.isEmpty && rivalries.all.isEmpty && playoffs.isEmpty
    }

    /// Facts worth featuring, minus any the caller already shows elsewhere.
    ///
    /// The hero card carries titles and seasons as headline stats, so repeating
    /// them as featured facts would say the same thing twice on one screen.
    func facts(excluding keys: Set<String>) -> [CareerFact] {
        facts.filter { !keys.contains($0.key) }
    }

    /// The timeline, most recent season first — how a profile is read.
    var timeline: [SeasonSummary] {
        seasons.sorted { ($0.season, $0.leagueName) > ($1.season, $1.leagueName) }
    }

    enum CodingKeys: String, CodingKey {
        case version, playoffs, streaks, seasons, draft, rivalries, facts
        case regularSeason = "regular_season"
        case bestSeason = "best_season"
        case worstSeason = "worst_season"
    }
}

extension CareerDetails {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = container.lenient(.version, 0)
        regularSeason = container.lenient(.regularSeason, .empty)
        playoffs = container.lenient(.playoffs, .empty)
        streaks = container.lenient(.streaks, .empty)
        seasons = container.lenient(.seasons, [])
        bestSeason = container.lenient(.bestSeason)
        worstSeason = container.lenient(.worstSeason)
        draft = container.lenient(.draft, .empty)
        rivalries = container.lenient(.rivalries, .empty)
        facts = container.lenient(.facts, [])
    }
}

// MARK: - Records

/// A won–lost–tied record with the points that produced it.
struct CareerRecord: Codable, Hashable, Sendable {
    let wins: Int
    let losses: Int
    let ties: Int
    let games: Int
    /// A tie counts as half a win. `nil` when nothing has been played — a new
    /// account has no win rate, and "0%" would be a lie.
    let winPercentage: Double?
    let pointsFor: Double
    let pointsAgainst: Double
    /// Over regular season weeks, which is what `pointsFor` covers.
    let pointsPerGame: Double?

    static let empty = CareerRecord(
        wins: 0, losses: 0, ties: 0, games: 0,
        winPercentage: nil, pointsFor: 0, pointsAgainst: 0, pointsPerGame: nil
    )

    /// "128–74" or "128–74–2". En dashes, not hyphens.
    var recordText: String { Record.text(wins: wins, losses: losses, ties: ties) }

    /// The margin across a career: positive when they have outscored opponents.
    var pointsDifferential: Double { pointsFor - pointsAgainst }

    enum CodingKeys: String, CodingKey {
        case wins, losses, ties, games
        case winPercentage = "win_pct"
        case pointsFor = "points_for"
        case pointsAgainst = "points_against"
        case pointsPerGame = "points_per_game"
    }
}

extension CareerRecord {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        wins = container.lenient(.wins, 0)
        losses = container.lenient(.losses, 0)
        ties = container.lenient(.ties, 0)
        games = container.lenient(.games, 0)
        winPercentage = container.lenient(.winPercentage)
        pointsFor = container.lenient(.pointsFor, 0)
        pointsAgainst = container.lenient(.pointsAgainst, 0)
        pointsPerGame = container.lenient(.pointsPerGame)
    }
}

/// Playoff results, read from the winners bracket rather than from playoff-week
/// matchups — those also contain the consolation bracket.
struct PlayoffRecord: Codable, Hashable, Sendable {
    let wins: Int
    let losses: Int
    let games: Int
    let winPercentage: Double?
    /// Seasons that reached the winners bracket.
    let appearances: Int
    let championships: Int
    let runnerUps: Int
    /// Championship games reached, won or lost.
    let finals: Int

    static let empty = PlayoffRecord(
        wins: 0, losses: 0, games: 0, winPercentage: nil,
        appearances: 0, championships: 0, runnerUps: 0, finals: 0
    )

    var recordText: String { Record.text(wins: wins, losses: losses, ties: 0) }

    /// Nothing to show: never been to the playoffs at all.
    var isEmpty: Bool { games == 0 && appearances == 0 && championships == 0 }

    enum CodingKeys: String, CodingKey {
        case wins, losses, games, appearances, championships, finals
        case winPercentage = "win_pct"
        case runnerUps = "runner_ups"
    }
}

extension PlayoffRecord {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        wins = container.lenient(.wins, 0)
        losses = container.lenient(.losses, 0)
        games = container.lenient(.games, 0)
        winPercentage = container.lenient(.winPercentage)
        appearances = container.lenient(.appearances, 0)
        championships = container.lenient(.championships, 0)
        runnerUps = container.lenient(.runnerUps, 0)
        finals = container.lenient(.finals, 0)
    }
}

// MARK: - Streaks

struct CareerStreaks: Codable, Hashable, Sendable {
    let longestWin: CareerStreak?
    let longestLoss: CareerStreak?

    static let empty = CareerStreaks(longestWin: nil, longestLoss: nil)

    var isEmpty: Bool { longestWin == nil && longestLoss == nil }

    enum CodingKeys: String, CodingKey {
        case longestWin = "longest_win"
        case longestLoss = "longest_loss"
    }
}

extension CareerStreaks {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        longestWin = container.lenient(.longestWin)
        longestLoss = container.lenient(.longestLoss)
    }
}

/// A run of consecutive results, always inside one league-season: someone in three
/// leagues at once plays three schedules, and merging them would invent streaks.
struct CareerStreak: Codable, Hashable, Sendable, Identifiable {
    let length: Int
    let leagueID: String
    let leagueName: String
    let season: Int
    let startWeek: Int
    let endWeek: Int

    var id: String { "\(leagueID)-\(season)-\(startWeek)" }

    /// "2023 · Dynasty Dads". The week range is deliberately not shown: a bye in
    /// the middle of a run makes "weeks 1–9" disagree with a length of 8.
    var context: String { "\(season) · \(leagueName)" }

    enum CodingKeys: String, CodingKey {
        case length, season
        case leagueID = "league_id"
        case leagueName = "league_name"
        case startWeek = "start_week"
        case endWeek = "end_week"
    }
}

extension CareerStreak {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        length = container.lenient(.length, 0)
        leagueID = container.lenient(.leagueID, "")
        leagueName = container.lenient(.leagueName, "")
        season = container.lenient(.season, 0)
        startWeek = container.lenient(.startWeek, 0)
        endWeek = container.lenient(.endWeek, 0)
    }
}

// MARK: - Seasons

/// One league-season: a row of the career timeline.
struct SeasonSummary: Codable, Hashable, Sendable, Identifiable {
    /// Where the record came from. `rosterTotals` means no weeks were stored for
    /// this league-season, so Sleeper's own season totals were used and the
    /// week-level numbers on this row are empty rather than wrong.
    enum RecordSource: String, Codable, Sendable {
        case matchups
        case rosterTotals = "roster_totals"
    }

    let season: Int
    let leagueID: String
    let leagueName: String
    let rosterID: Int
    let teamName: String?
    let wins: Int
    let losses: Int
    let ties: Int
    let games: Int
    let winPercentage: Double?
    let pointsFor: Double
    let pointsAgainst: Double
    let pointsPerGame: Double?
    let playoffPointsFor: Double
    let highWeek: Double?
    let lowWeek: Double?
    /// Regular season weeks with a score, byes included.
    let regularWeeks: Int
    /// Every week with a score, playoff and consolation games included.
    let weeksPlayed: Int
    let finishRank: Int?
    let playoffWins: Int
    let playoffLosses: Int
    let madePlayoffs: Bool
    let champion: Bool
    let runnerUp: Bool
    /// Still being played, so the record is not final.
    let inProgress: Bool
    /// Results include a weekly match against the league median.
    let medianScoring: Bool
    let recordSource: RecordSource

    /// A roster is unique within a league, and a league id is unique to a season.
    var id: String { "\(leagueID)-\(rosterID)" }

    var recordText: String { Record.text(wins: wins, losses: losses, ties: ties) }

    /// "1st", "2nd", "11th" — localized, so it is not a hand-rolled suffix table.
    var finishText: String? {
        guard let finishRank, finishRank > 0 else { return nil }
        return Self.ordinal.string(from: NSNumber(value: finishRank))
    }

    /// Nothing was played: a league connected before its season started.
    var isUnplayed: Bool { games == 0 && weeksPlayed == 0 }

    /// "124.8" — points a week. `nil` when no weeks were stored for the season,
    /// which is the case for a record taken from Sleeper's roster totals.
    var perWeekText: String? {
        pointsPerGame?.formatted(.number.precision(.fractionLength(1)))
    }

    // Explicitly `nonisolated` so the ordinal is reachable off the main actor:
    // under this project's default-MainActor isolation an unannotated static
    // would not be, and a season row is decoded and tested away from the UI.
    nonisolated private static let ordinal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter
    }()

    enum CodingKeys: String, CodingKey {
        case season, wins, losses, ties, games, champion
        case leagueID = "league_id"
        case leagueName = "league_name"
        case rosterID = "roster_id"
        case teamName = "team_name"
        case winPercentage = "win_pct"
        case pointsFor = "points_for"
        case pointsAgainst = "points_against"
        case pointsPerGame = "points_per_game"
        case playoffPointsFor = "playoff_points_for"
        case highWeek = "high_week"
        case lowWeek = "low_week"
        case regularWeeks = "regular_weeks"
        case weeksPlayed = "weeks_played"
        case finishRank = "finish_rank"
        case playoffWins = "playoff_wins"
        case playoffLosses = "playoff_losses"
        case madePlayoffs = "made_playoffs"
        case runnerUp = "runner_up"
        case inProgress = "in_progress"
        case medianScoring = "median_scoring"
        case recordSource = "record_source"
    }
}

extension SeasonSummary {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        season = container.lenient(.season, 0)
        leagueID = container.lenient(.leagueID, "")
        leagueName = container.lenient(.leagueName, "")
        rosterID = container.lenient(.rosterID, 0)
        teamName = container.lenient(.teamName)
        wins = container.lenient(.wins, 0)
        losses = container.lenient(.losses, 0)
        ties = container.lenient(.ties, 0)
        games = container.lenient(.games, 0)
        winPercentage = container.lenient(.winPercentage)
        pointsFor = container.lenient(.pointsFor, 0)
        pointsAgainst = container.lenient(.pointsAgainst, 0)
        pointsPerGame = container.lenient(.pointsPerGame)
        playoffPointsFor = container.lenient(.playoffPointsFor, 0)
        highWeek = container.lenient(.highWeek)
        lowWeek = container.lenient(.lowWeek)
        regularWeeks = container.lenient(.regularWeeks, 0)
        weeksPlayed = container.lenient(.weeksPlayed, 0)
        finishRank = container.lenient(.finishRank)
        playoffWins = container.lenient(.playoffWins, 0)
        playoffLosses = container.lenient(.playoffLosses, 0)
        madePlayoffs = container.lenient(.madePlayoffs, false)
        champion = container.lenient(.champion, false)
        runnerUp = container.lenient(.runnerUp, false)
        inProgress = container.lenient(.inProgress, false)
        medianScoring = container.lenient(.medianScoring, false)
        // An unrecognised source means a newer server; assume the normal path
        // rather than throwing the season away.
        recordSource = RecordSource(rawValue: container.lenient(.recordSource, "")) ?? .matchups
    }
}

// MARK: - Draft

struct DraftGrades: Codable, Hashable, Sendable {
    let bestPicks: [DraftPickGrade]
    let worstPicks: [DraftPickGrade]
    /// How many picks could be scored at all.
    let scoredPicks: Int
    /// League-seasons the user played but where no usable draft was stored.
    let leaguesMissingDraftData: Int

    static let empty = DraftGrades(
        bestPicks: [], worstPicks: [], scoredPicks: 0, leaguesMissingDraftData: 0
    )

    var isEmpty: Bool { bestPicks.isEmpty && worstPicks.isEmpty }

    enum CodingKeys: String, CodingKey {
        case bestPicks = "best_picks"
        case worstPicks = "worst_picks"
        case scoredPicks = "scored_picks"
        case leaguesMissingDraftData = "leagues_missing_draft_data"
    }
}

extension DraftGrades {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bestPicks = container.lenient(.bestPicks, [])
        worstPicks = container.lenient(.worstPicks, [])
        scoredPicks = container.lenient(.scoredPicks, 0)
        leaguesMissingDraftData = container.lenient(.leaguesMissingDraftData, 0)
    }
}

/// One drafted player, graded on what he returned in this manager's starting
/// lineup against what the rest of his round returned.
struct DraftPickGrade: Codable, Hashable, Sendable, Identifiable {
    let playerID: String
    let playerName: String?
    let position: String?
    let season: Int
    let leagueID: String
    let leagueName: String
    let round: Int
    /// Sleeper's overall pick number within the draft.
    let pick: Int
    let draftSlot: Int?
    /// Points scored while in this manager's starting lineup that season.
    let points: Double
    /// What the rest of the same round of the same draft returned.
    let expectedPoints: Double
    /// `points` − `expectedPoints`. Positive is a steal, negative is a bust.
    let surplus: Double

    var id: String { "\(leagueID)-\(pick)-\(playerID)" }

    var displayName: String { playerName ?? "Unknown player" }

    /// "9.01" — the round-and-slot notation drafters actually use. Falls back to
    /// the overall pick number when Sleeper recorded no slot.
    var slotText: String {
        guard let draftSlot, draftSlot > 0 else { return "Pick \(pick)" }
        return "\(round).\(String(format: "%02d", draftSlot))"
    }

    /// "308" — a season total, where the decimal is noise.
    var pointsText: String { points.formatted(.number.precision(.fractionLength(0))) }

    /// "+266" / "−371" against the round. A true minus sign, not a hyphen.
    var surplusText: String {
        let rounded = abs(surplus).formatted(.number.precision(.fractionLength(0)))
        return surplus < 0 ? "−\(rounded)" : "+\(rounded)"
    }

    enum CodingKeys: String, CodingKey {
        case position, season, round, pick, points, surplus
        case playerID = "player_id"
        case playerName = "player_name"
        case leagueID = "league_id"
        case leagueName = "league_name"
        case draftSlot = "draft_slot"
        case expectedPoints = "expected_points"
    }
}

extension DraftPickGrade {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playerID = container.lenient(.playerID, "")
        playerName = container.lenient(.playerName)
        position = container.lenient(.position)
        season = container.lenient(.season, 0)
        leagueID = container.lenient(.leagueID, "")
        leagueName = container.lenient(.leagueName, "")
        round = container.lenient(.round, 0)
        pick = container.lenient(.pick, 0)
        draftSlot = container.lenient(.draftSlot)
        points = container.lenient(.points, 0)
        expectedPoints = container.lenient(.expectedPoints, 0)
        surplus = container.lenient(.surplus, 0)
    }
}

// MARK: - Rivalries

struct RivalrySummary: Codable, Hashable, Sendable {
    /// Meetings needed before a head-to-head counts as a rivalry.
    let threshold: Int
    /// Every qualifying rivalry, most-played first.
    let all: [Rivalry]
    let mostPlayed: Rivalry?
    /// The opponent beaten most often.
    let best: Rivalry?
    /// The opponent who has won most often.
    let worst: Rivalry?

    static let empty = RivalrySummary(
        threshold: 0, all: [], mostPlayed: nil, best: nil, worst: nil
    )

    /// The three roles worth featuring, with duplicates merged.
    ///
    /// One opponent very often holds more than one role — the person you have
    /// played most is frequently also the person you have beaten most. Listing
    /// them two or three times would read as a bug, so the roles collapse onto a
    /// single entry instead.
    var highlights: [RivalryHighlight] {
        var ordered: [String] = []
        var roles: [String: [RivalryHighlight.Role]] = [:]
        var rivals: [String: Rivalry] = [:]

        for (rivalry, role) in [
            (mostPlayed, RivalryHighlight.Role.mostPlayed),
            (best, .beatenMost),
            (worst, .losesTo),
        ] {
            guard let rivalry else { continue }
            let key = rivalry.opponentKey
            if rivals[key] == nil {
                rivals[key] = rivalry
                ordered.append(key)
            }
            roles[key, default: []].append(role)
        }

        return ordered.compactMap { key in
            guard let rivalry = rivals[key], let roles = roles[key] else { return nil }
            return RivalryHighlight(rivalry: rivalry, roles: roles)
        }
    }

    enum CodingKeys: String, CodingKey {
        case threshold, all, best, worst
        case mostPlayed = "most_played"
    }
}

extension RivalrySummary {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        threshold = container.lenient(.threshold, 0)
        all = container.lenient(.all, [])
        mostPlayed = container.lenient(.mostPlayed)
        best = container.lenient(.best)
        worst = container.lenient(.worst)
    }
}

/// A head-to-head record against one opponent, across every league and season.
struct Rivalry: Codable, Hashable, Sendable, Identifiable {
    /// A Sleeper user id, or `orphan:<league>:<roster>` for an unmanaged team.
    let opponentKey: String
    let opponentUserID: String?
    let name: String
    let games: Int
    let wins: Int
    let losses: Int
    let ties: Int
    let winPercentage: Double?
    let pointsFor: Double
    let pointsAgainst: Double
    /// Every season they have met in, oldest first.
    let seasons: [Int]

    var id: String { opponentKey }

    var recordText: String { Record.text(wins: wins, losses: losses, ties: ties) }

    /// The first season they ever played, for "since 2019".
    var firstSeason: Int? { seasons.first }

    enum CodingKeys: String, CodingKey {
        case name, games, wins, losses, ties, seasons
        case opponentKey = "opponent_key"
        case opponentUserID = "opponent_user_id"
        case winPercentage = "win_pct"
        case pointsFor = "points_for"
        case pointsAgainst = "points_against"
    }
}

extension Rivalry {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        opponentKey = container.lenient(.opponentKey, "")
        opponentUserID = container.lenient(.opponentUserID)
        name = container.lenient(.name, "Unknown team")
        games = container.lenient(.games, 0)
        wins = container.lenient(.wins, 0)
        losses = container.lenient(.losses, 0)
        ties = container.lenient(.ties, 0)
        winPercentage = container.lenient(.winPercentage)
        pointsFor = container.lenient(.pointsFor, 0)
        pointsAgainst = container.lenient(.pointsAgainst, 0)
        seasons = container.lenient(.seasons, [])
    }
}

/// A rivalry plus why it is being featured. Built by
/// ``RivalrySummary/highlights``; not part of the payload.
struct RivalryHighlight: Hashable, Sendable, Identifiable {
    enum Role: Hashable, Sendable {
        case mostPlayed
        /// Beaten more often than anyone else.
        case beatenMost
        /// Has beaten this manager more often than anyone else.
        case losesTo
    }

    let rivalry: Rivalry
    /// In payload order: most played, then beaten most, then loses to.
    let roles: [Role]

    var id: String { rivalry.opponentKey }
}

// MARK: - Facts

/// One number worth featuring big on the profile, with the context that makes it
/// mean something.
struct CareerFact: Codable, Hashable, Sendable, Identifiable {
    /// What the number is counted in. Decides how it is formatted, not what it
    /// says — the label comes from the server so a new fact needs no release.
    enum Unit: String, Codable, Sendable {
        case points, count, seasons, games
    }

    /// The keys this build knows about by name. The server may send others; they
    /// render from `label` and `unit` alone, which is the point of carrying both.
    enum Key {
        static let seasonsPlayed = "seasons_played"
        static let championships = "championships"
        static let highestWeek = "highest_week"
        static let closestWin = "closest_win"
        static let biggestWin = "biggest_win"
        static let longestWinStreak = "longest_win_streak"
        static let pointsFor = "points_for"
    }

    let key: String
    /// Already written for display, in the app's voice.
    let label: String
    let value: Double
    let unit: Unit
    let season: Int?
    let week: Int?
    let leagueName: String?
    let opponent: String?
    let margin: Double?

    var id: String { key }

    /// Points keep a decimal; counts of things never do.
    var decimals: Int { unit == .points ? 1 : 0 }

    /// "Week 16 · 2023", or just "2023". `nil` when the fact is a career total
    /// that did not happen at a moment in time.
    var context: String? {
        var parts: [String] = []
        if let week { parts.append("Week \(week)") }
        if let season { parts.append(String(season)) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    enum CodingKeys: String, CodingKey {
        case key, label, value, unit, season, week, opponent, margin
        case leagueName = "league_name"
    }
}

extension CareerFact {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = container.lenient(.key, "")
        label = container.lenient(.label, "")
        value = container.lenient(.value, 0)
        // An unrecognised unit still formats sensibly as a whole number.
        unit = Unit(rawValue: container.lenient(.unit, "")) ?? .count
        season = container.lenient(.season)
        week = container.lenient(.week)
        leagueName = container.lenient(.leagueName)
        opponent = container.lenient(.opponent)
        margin = container.lenient(.margin)
    }
}

// MARK: - Shared formatting

/// Record text in one place, so "128–74–2" is punctuated the same everywhere.
///
/// `nonisolated` because it is a pure function of two integers, and it is called
/// from places that are not the main actor — a wrap card's share title is built
/// while the image is being exported.
nonisolated enum Record {
    /// En dashes, and the ties component only when there are ties.
    static func text(wins: Int, losses: Int, ties: Int) -> String {
        ties > 0 ? "\(wins)–\(losses)–\(ties)" : "\(wins)–\(losses)"
    }
}

// MARK: - Lenient decoding

/// Fallback-on-anything accessors, **scoped to this file on purpose**.
///
/// Strict decoding is the right default everywhere else in `Models/`: a malformed
/// `leagues` row is a bug worth surfacing loudly. This payload is the one
/// exception — it is a server-computed cache whose shape is allowed to move ahead
/// of the installed app, so tolerating drift here is the correct trade.
private extension KeyedDecodingContainer {
    /// The value, or `fallback` when the key is absent, null, or the wrong type.
    func lenient<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
    }

    /// The value, or `nil` when the key is absent, null, or the wrong type.
    func lenient<T: Decodable>(_ key: Key) -> T? {
        (try? decodeIfPresent(T.self, forKey: key)) ?? nil
    }
}
