import Foundation
import Testing
@testable import Benchd

/// Decoding the `career_stats.details` payload.
///
/// The fixture below is **real output**: it is what
/// `supabase/functions/_shared/career.ts` produced for a synthetic three-season
/// career, captured verbatim rather than written by hand. A guess at the payload
/// would pass these tests while the app showed an empty profile against the live
/// server, which is the failure worth designing the fixture around.
///
/// It covers, on purpose: a median-scoring season, a championship season, a season
/// still in progress, a draft steal and a first-round bust, three rivalries with one
/// person holding two roles, and a null win percentage.
struct CareerDetailsDecodingTests {

    /// One `details` object, as the edge function writes it.
    private static let payload = """
    {"version":1,"regular_season":{"wins":33,"losses":13,"ties":0,"games":46,"win_pct":0.7\
    2,"points_for":3678.7,"points_against":3216,"points_per_game":114.96},"playoffs":{"win\
    s":2,"losses":1,"games":3,"win_pct":0.67,"appearances":2,"championships":1,"runner_ups\
    ":1,"finals":2},"streaks":{"longest_win":{"league_id":"784462448236949504","league_nam\
    e":"Dynasty Dads","season":2023,"length":9,"start_week":1,"end_week":9},"longest_loss"\
    :{"league_id":"784462448236949504","league_name":"Dynasty Dads","season":2023,"length"\
    :5,"start_week":10,"end_week":14}},"seasons":[{"season":2022,"league_id":"917461823049\
    281536","league_name":"Work League","roster_id":3,"team_name":"Bench Mob","wins":20,"l\
    osses":8,"ties":0,"games":28,"win_pct":0.71,"points_for":1540.2,"points_against":1407,\
    "points_per_game":110.01,"playoff_points_for":0,"high_week":118.66,"low_week":88.4,"re\
    gular_weeks":14,"weeks_played":14,"finish_rank":5,"playoff_wins":0,"playoff_losses":1,\
    "made_playoffs":true,"champion":false,"runner_up":true,"in_progress":false,"median_sco\
    ring":true,"record_source":"matchups"},{"season":2023,"league_id":"784462448236949504"\
    ,"league_name":"Dynasty Dads","roster_id":3,"team_name":"Bench Mob","wins":9,"losses":\
    5,"ties":0,"games":14,"win_pct":0.64,"points_for":1605.38,"points_against":1407,"point\
    s_per_game":114.67,"playoff_points_for":279.82,"high_week":148.62,"low_week":96.4,"reg\
    ular_weeks":14,"weeks_played":16,"finish_rank":1,"playoff_wins":2,"playoff_losses":0,"\
    made_playoffs":true,"champion":true,"runner_up":false,"in_progress":false,"median_scor\
    ing":false,"record_source":"matchups"},{"season":2026,"league_id":"1131742819283746816\
    ","league_name":"Dynasty Dads","roster_id":7,"team_name":"Bench Mob","wins":4,"losses"\
    :0,"ties":0,"games":4,"win_pct":1,"points_for":533.12,"points_against":402,"points_per\
    _game":133.28,"playoff_points_for":0,"high_week":133.28,"low_week":133.28,"regular_wee\
    ks":4,"weeks_played":4,"finish_rank":null,"playoff_wins":0,"playoff_losses":0,"made_pl\
    ayoffs":false,"champion":false,"runner_up":false,"in_progress":true,"median_scoring":f\
    alse,"record_source":"matchups"}],"best_season":{"season":2022,"league_id":"9174618230\
    49281536","league_name":"Work League","roster_id":3,"team_name":"Bench Mob","wins":20,\
    "losses":8,"ties":0,"games":28,"win_pct":0.71,"points_for":1540.2,"points_against":140\
    7,"points_per_game":110.01,"playoff_points_for":0,"high_week":118.66,"low_week":88.4,"\
    regular_weeks":14,"weeks_played":14,"finish_rank":5,"playoff_wins":0,"playoff_losses":\
    1,"made_playoffs":true,"champion":false,"runner_up":true,"in_progress":false,"median_s\
    coring":true,"record_source":"matchups"},"worst_season":{"season":2023,"league_id":"78\
    4462448236949504","league_name":"Dynasty Dads","roster_id":3,"team_name":"Bench Mob","\
    wins":9,"losses":5,"ties":0,"games":14,"win_pct":0.64,"points_for":1605.38,"points_aga\
    inst":1407,"points_per_game":114.67,"playoff_points_for":279.82,"high_week":148.62,"lo\
    w_week":96.4,"regular_weeks":14,"weeks_played":16,"finish_rank":1,"playoff_wins":2,"pl\
    ayoff_losses":0,"made_playoffs":true,"champion":true,"runner_up":false,"in_progress":f\
    alse,"median_scoring":false,"record_source":"matchups"},"draft":{"best_picks":[{"playe\
    r_id":"9493","player_name":"Puka Nacua","position":"WR","season":2023,"league_id":"784\
    462448236949504","league_name":"Dynasty Dads","round":9,"pick":33,"draft_slot":1,"poin\
    ts":308,"expected_points":42,"surplus":266},{"player_id":"6794","player_name":"Justin \
    Jefferson","position":"WR","season":2023,"league_id":"784462448236949504","league_name\
    ":"Dynasty Dads","round":2,"pick":5,"draft_slot":1,"points":336,"expected_points":336,\
    "surplus":0},{"player_id":"4034","player_name":"Christian McCaffrey","position":"RB","\
    season":2023,"league_id":"784462448236949504","league_name":"Dynasty Dads","round":3,"\
    pick":9,"draft_slot":1,"points":294,"expected_points":294,"surplus":0}],"worst_picks":\
    [{"player_id":"4035","player_name":"Jonathan Taylor","position":"RB","season":2023,"le\
    ague_id":"784462448236949504","league_name":"Dynasty Dads","round":1,"pick":1,"draft_s\
    lot":1,"points":7,"expected_points":378,"surplus":-371},{"player_id":"308","player_nam\
    e":"Player 3-8","position":"WR","season":2023,"league_id":"784462448236949504","league\
    _name":"Dynasty Dads","round":8,"pick":29,"draft_slot":1,"points":84,"expected_points"\
    :84,"surplus":0},{"player_id":"307","player_name":"Player 3-7","position":"WR","season\
    ":2023,"league_id":"784462448236949504","league_name":"Dynasty Dads","round":7,"pick":\
    25,"draft_slot":1,"points":126,"expected_points":126,"surplus":0}],"scored_picks":9,"l\
    eagues_missing_draft_data":2},"rivalries":{"threshold":4,"all":[{"opponent_key":"11111\
    1111111111111","opponent_user_id":"111111111111111111","name":"Dana Mode","games":14,"\
    wins":12,"losses":2,"ties":0,"win_pct":0.86,"points_for":1706.94,"points_against":1455\
    .3,"seasons":[2022,2023,2026]},{"opponent_key":"222222222222222222","opponent_user_id"\
    :"222222222222222222","name":"Omar United","games":11,"wins":9,"losses":2,"ties":0,"wi\
    n_pct":0.82,"points_for":1293.84,"points_against":1105.5,"seasons":[2022,2023,2026]},{\
    "opponent_key":"333333333333333333","opponent_user_id":"333333333333333333","name":"Pr\
    iya FC","games":9,"wins":4,"losses":5,"ties":0,"win_pct":0.44,"points_for":957.74,"poi\
    nts_against":904.5,"seasons":[2022,2023,2026]}],"most_played":{"opponent_key":"1111111\
    11111111111","opponent_user_id":"111111111111111111","name":"Dana Mode","games":14,"wi\
    ns":12,"losses":2,"ties":0,"win_pct":0.86,"points_for":1706.94,"points_against":1455.3\
    ,"seasons":[2022,2023,2026]},"best":{"opponent_key":"111111111111111111","opponent_use\
    r_id":"111111111111111111","name":"Dana Mode","games":14,"wins":12,"losses":2,"ties":0\
    ,"win_pct":0.86,"points_for":1706.94,"points_against":1455.3,"seasons":[2022,2023,2026\
    ]},"worst":{"opponent_key":"333333333333333333","opponent_user_id":"333333333333333333\
    ","name":"Priya FC","games":9,"wins":4,"losses":5,"ties":0,"win_pct":0.44,"points_for"\
    :957.74,"points_against":904.5,"seasons":[2022,2023,2026]}},"facts":[{"key":"seasons_p\
    layed","label":"Seasons \
    played","value":3,"unit":"seasons"},{"key":"highest_week","label":"Highest week \
    ever","value":148.62,"unit":"points","season":2023,"week":15,"league_name":"Dynasty \
    Dads","opponent":"Dana Mode"},{"key":"closest_win","label":"Closest \
    win","value":12.3,"unit":"points","season":2023,"week":16,"league_name":"Dynasty \
    Dads","opponent":"Dana Mode","margin":12.3},{"key":"biggest_win","label":"Biggest \
    blowout","value":32.78,"unit":"points","season":2026,"week":1,"league_name":"Dynasty \
    Dads","opponent":"Dana Mode","margin":32.78},{"key":"championships","label":"Champions\
    hips","value":1,"unit":"count"},{"key":"longest_win_streak","label":"Longest win \
    streak","value":9,"unit":"games","season":2023,"league_name":"Dynasty \
    Dads"},{"key":"points_for","label":"Points scored, all \
    time","value":3678.7,"unit":"points"}]}
    """

    private static func decoded() throws -> CareerDetails {
        try PostgrestCoding.decoder.decode(CareerDetails.self, from: Data(payload.utf8))
    }

    // MARK: - The whole payload

    @Test("The details payload the edge function writes decodes whole")
    func decodesRealPayload() throws {
        let details = try Self.decoded()

        #expect(details.version == 1)
        #expect(details.isEmpty == false)

        #expect(details.regularSeason.wins == 33)
        #expect(details.regularSeason.losses == 13)
        #expect(details.regularSeason.games == 46)
        #expect(details.regularSeason.winPercentage == 0.72)
        #expect(details.regularSeason.pointsFor == 3678.7)
        #expect(details.regularSeason.pointsPerGame == 114.96)
        #expect(details.regularSeason.recordText == "33–13")

        #expect(details.playoffs.championships == 1)
        #expect(details.playoffs.runnerUps == 1)
        #expect(details.playoffs.finals == 2)
        #expect(details.playoffs.appearances == 2)
        #expect(details.playoffs.recordText == "2–1")

        #expect(details.seasons.count == 3)
        #expect(details.facts.count == 7)
        #expect(details.draft.bestPicks.count == 3)
        #expect(details.draft.worstPicks.count == 3)
        #expect(details.rivalries.all.count == 3)
    }

    @Test("Streaks decode with the league-season they happened in")
    func streaks() throws {
        let streaks = try Self.decoded().streaks
        let win = try #require(streaks.longestWin)

        #expect(win.length == 9)
        #expect(win.season == 2023)
        #expect(win.leagueName == "Dynasty Dads")
        #expect(win.startWeek == 1)
        #expect(win.endWeek == 9)
        #expect(win.context == "2023 · Dynasty Dads")
        #expect(streaks.longestLoss?.length == 5)
        #expect(streaks.longestLoss?.startWeek == 10)
    }

    @Test("Season rows keep the median flag, the finish, and the record source")
    func seasonRows() throws {
        let seasons = try Self.decoded().seasons
        let median = try #require(seasons.first { $0.season == 2022 })
        let title = try #require(seasons.first { $0.season == 2023 })
        let live = try #require(seasons.first { $0.season == 2026 })

        // 28 results out of 14 weeks: the median match is the second one each week.
        #expect(median.medianScoring)
        #expect(median.games == 28)
        #expect(median.regularWeeks == 14)
        #expect(median.recordText == "20–8")

        #expect(title.champion)
        #expect(title.finishRank == 1)
        #expect(title.finishText == "1st")
        #expect(title.playoffWins == 2)
        #expect(title.weeksPlayed > title.regularWeeks) // playoff weeks are in there
        #expect(title.recordSource == .matchups)
        #expect(title.inProgress == false)

        #expect(live.inProgress)
        #expect(live.champion == false)
        #expect(live.finishRank == nil)
        #expect(live.finishText == nil)
    }

    @Test("Draft grades carry the round baseline the surplus is measured against")
    func draftGrades() throws {
        let draft = try Self.decoded().draft
        let steal = try #require(draft.bestPicks.first)
        let bust = try #require(draft.worstPicks.first)

        #expect(steal.playerName == "Puka Nacua")
        #expect(steal.position == "WR")
        #expect(steal.round == 9)
        #expect(steal.points == 308)
        #expect(steal.expectedPoints == 42)
        #expect(steal.surplus == 266)
        #expect(steal.surplusText == "+266")

        #expect(bust.playerName == "Jonathan Taylor")
        #expect(bust.round == 1)
        #expect(bust.surplus == -371)
        #expect(draft.scoredPicks == 9)
        // Two of the three seasons had no draft stored at all.
        #expect(draft.leaguesMissingDraftData == 2)
        #expect(draft.isEmpty == false)
    }

    @Test("Rivalries decode with every season they have met in")
    func rivalries() throws {
        let rivalries = try Self.decoded().rivalries
        let mostPlayed = try #require(rivalries.mostPlayed)

        #expect(rivalries.threshold == 4)
        #expect(mostPlayed.name == "Dana Mode")
        #expect(mostPlayed.games == 14)
        #expect(mostPlayed.recordText == "12–2")
        #expect(mostPlayed.seasons == [2022, 2023, 2026])
        #expect(mostPlayed.firstSeason == 2022)
        #expect(rivalries.worst?.name == "Priya FC")
        // Every rivalry cleared the four-meeting threshold.
        #expect(rivalries.all.allSatisfy { $0.games >= rivalries.threshold })
    }

    @Test("Facts keep their unit, their context, and their precision")
    func facts() throws {
        let facts = try Self.decoded().facts
        let highest = try #require(facts.first { $0.key == CareerFact.Key.highestWeek })
        let seasons = try #require(facts.first { $0.key == CareerFact.Key.seasonsPlayed })

        #expect(highest.label == "Highest week ever")
        #expect(highest.value == 148.62)
        #expect(highest.unit == .points)
        #expect(highest.season == 2023)
        #expect(highest.week == 15)
        #expect(highest.opponent == "Dana Mode")
        #expect(highest.context == "Week 15 · 2023")
        // Points keep a decimal; a count of seasons never does.
        #expect(highest.decimals == 1)
        #expect(seasons.decimals == 0)
        #expect(seasons.context == nil)
    }

    // MARK: - Payloads this build was not written for

    @Test("A details value of {} decodes to nothing, not to a failure")
    func emptyObject() throws {
        // Every row written before the details existed looks like this.
        let details = try PostgrestCoding.decoder.decode(
            CareerDetails.self, from: Data("{}".utf8)
        )
        #expect(details.isEmpty)
        #expect(details.version == 0)
        #expect(details.regularSeason.winPercentage == nil)
        #expect(details.rivalries.highlights.isEmpty)
    }

    @Test("Unknown keys and unknown enum values are tolerated, not rejected")
    func forwardCompatible() throws {
        // A newer server: a section this build has never heard of, a fact in a unit
        // it does not know, and a record source it cannot name. None of it may cost
        // the payload.
        let json = """
        {
          "version": 9,
          "wraps_shared": {"count": 12},
          "seasons": [{"season": 2023, "league_id": "l", "league_name": "Dynasty Dads",
                       "roster_id": 3, "wins": 9, "losses": 5, "ties": 0,
                       "record_source": "something_new", "mvp": "Puka Nacua"}],
          "facts": [{"key": "coldest_week", "label": "Coldest week", "value": 61.4,
                     "unit": "degrees"}]
        }
        """
        let details = try PostgrestCoding.decoder.decode(
            CareerDetails.self, from: Data(json.utf8)
        )

        #expect(details.version == 9)
        #expect(details.seasons.count == 1)
        #expect(details.seasons[0].recordSource == .matchups)
        #expect(details.seasons[0].recordText == "9–5")
        // An unrecognised unit still formats as a whole number rather than crashing.
        #expect(details.facts[0].unit == .count)
        #expect(details.facts[0].label == "Coldest week")
    }

    @Test("A malformed details payload cannot take the row down with it")
    func malformedDetailsKeepsTheRow() throws {
        // The headline columns are what most of the profile is made of. Whatever has
        // happened to `details`, they have to survive it.
        for broken in ["[]", "\"nonsense\"", "12", "null"] {
            let row = """
            {"sleeper_account_id":"a4acd87b-557e-4b81-92ac-19d5b9129822","wins":33,\
            "losses":13,"ties":0,"championships":1,"seasons":3,"leagues_count":3,\
            "points_for":3678.7,"points_against":3216,"details":\(broken),\
            "computed_at":"2026-09-23T00:08:55.33+00:00"}
            """
            let stats = try PostgrestCoding.decoder.decode(
                CareerStats.self, from: Data(row.utf8)
            )
            #expect(stats.wins == 33, "wins lost for details: \(broken)")
            #expect(stats.championships == 1)
            #expect(stats.details.isEmpty, "details should be empty for \(broken)")
        }
    }

    @Test("A row whose details are a wholly different shape still renders its numbers")
    func unrelatedDetailsShape() throws {
        let row = """
        {"sleeper_account_id":"a4acd87b-557e-4b81-92ac-19d5b9129822","wins":7,\
        "losses":7,"ties":0,"championships":0,"seasons":5,"leagues_count":6,\
        "points_for":1953.28,"points_against":1741.74,\
        "details":{"best_pick":{"player_id":"4046","round":7}},\
        "computed_at":"2026-09-22T23:26:50.33+00:00"}
        """
        let stats = try PostgrestCoding.decoder.decode(CareerStats.self, from: Data(row.utf8))

        #expect(stats.recordText == "7–7")
        #expect(stats.details.isEmpty)
    }
}

// MARK: - Shaping

/// The derived values the profile renders — ordering, de-duplication, and the small
/// pieces of formatting that would otherwise be retyped in a view.
///
/// `@MainActor` because these reach `ProfileContent`, which is a `View` and so
/// main-actor isolated under this project's default isolation.
@MainActor
struct CareerDetailsShapingTests {

    @Test("The timeline runs newest first, however the payload was ordered")
    func timelineOrder() {
        // The server writes seasons oldest first; a profile reads the other way.
        let timeline = CareerDetails.sample.timeline
        #expect(timeline.map(\.season) == [2026, 2023, 2022])
        #expect(CareerDetails.sample.seasons.map(\.season) == [2022, 2023, 2026])
    }

    @Test("Facts the rest of the page already shows are filtered out")
    func factFiltering() {
        let featured = CareerDetails.sample.facts(excluding: ProfileContent.factsShownElsewhere)

        #expect(featured.count == 3)
        #expect(featured.map(\.key) == [
            CareerFact.Key.highestWeek,
            CareerFact.Key.closestWin,
            CareerFact.Key.biggestWin,
        ])
        // Titles, seasons, the points total and the win streak all have their own
        // place on the screen.
        #expect(!featured.contains { $0.key == CareerFact.Key.championships })
        #expect(!featured.contains { $0.key == CareerFact.Key.pointsFor })
    }

    @Test("Excluding nothing keeps every fact")
    func factFilteringEmptySet() {
        #expect(CareerDetails.sample.facts(excluding: []).count == 7)
    }

    @Test("One rival holding every role is listed once, with all three roles")
    func rivalRolesMerge() {
        // The person you have played most is very often the person you have beaten
        // most. Three rows for one person would read as a bug.
        let summary = RivalrySummary(
            threshold: 4,
            all: [.sampleNemesis],
            mostPlayed: .sampleNemesis,
            best: .sampleNemesis,
            worst: .sampleNemesis
        )

        let highlights = summary.highlights
        #expect(highlights.count == 1)
        #expect(highlights[0].roles == [.mostPlayed, .beatenMost, .losesTo])
        #expect(highlights[0].id == Rivalry.sampleNemesis.opponentKey)
    }

    @Test("Distinct rivals keep payload order: most played, beaten most, loses to")
    func rivalRoleOrder() {
        let highlights = CareerDetails.sample.rivalries.highlights

        #expect(highlights.count == 2)
        #expect(highlights[0].rivalry.name == "Dana Mode")
        #expect(highlights[0].roles == [.mostPlayed, .beatenMost])
        #expect(highlights[1].rivalry.name == "Priya FC")
        #expect(highlights[1].roles == [.losesTo])
    }

    @Test("No rivalries means no highlights, not an empty row")
    func noRivals() {
        #expect(RivalrySummary.empty.highlights.isEmpty)
    }

    @Test("A finish is an ordinal, and absent while a season is unfinished")
    func finishText() {
        #expect(SeasonSummary.sampleChampionship.finishText == "1st")
        #expect(SeasonSummary.sampleMedian.finishText == "5th")
        #expect(SeasonSummary.sampleInProgress.finishText == nil)
        #expect(SeasonSummary.sampleUnplayed.finishText == nil)
    }

    @Test("A draft pick reads as round.slot, falling back to the overall pick")
    func slotText() {
        #expect(DraftPickGrade.sampleSteal.slotText == "9.01")
        #expect(DraftPickGrade.sampleNoSlot.slotText == "Pick 33")
    }

    @Test("Surplus is signed with a true minus, and points drop the decimal")
    func pickFormatting() throws {
        #expect(DraftPickGrade.sampleSteal.surplusText == "+266")
        #expect(DraftPickGrade.sampleSteal.pointsText == "308")

        let bust = try #require(CareerDetails.sample.draft.worstPicks.first)
        #expect(bust.surplusText == "−371")       // U+2212, not a hyphen
        #expect(bust.surplusText.contains("-") == false)
    }

    @Test("A pick with no name still has something to render")
    func unnamedPick() {
        #expect(DraftPickGrade.sampleNoSlot.displayName == "Unknown player")
        #expect(DraftPickGrade.sampleSteal.displayName == "Puka Nacua")
    }

    @Test("Record text shows ties only when there are ties")
    func recordText() {
        #expect(Record.text(wins: 33, losses: 13, ties: 0) == "33–13")
        #expect(Record.text(wins: 128, losses: 74, ties: 2) == "128–74–2")
        #expect(Record.text(wins: 0, losses: 0, ties: 0) == "0–0")
    }

    @Test("A season with no weeks played says so rather than showing an average")
    func unplayedSeason() {
        let season = SeasonSummary.sampleUnplayed
        #expect(season.isUnplayed)
        #expect(season.perWeekText == nil)
        #expect(season.recordSource == .rosterTotals)
        #expect(SeasonSummary.sampleChampionship.perWeekText == "124.8")
    }

    @Test("isEmpty is true only when there is nothing at all to render")
    func isEmpty() {
        #expect(CareerDetails.empty.isEmpty)
        #expect(CareerDetails.sample.isEmpty == false)
        // One in-progress season with a couple of facts is still worth a page.
        #expect(CareerDetails.sampleFirstSeason.isEmpty == false)
    }

    @Test("An account in its first month has no playoffs, draft, or rivals to show")
    func firstSeasonSections() {
        let details = CareerDetails.sampleFirstSeason

        #expect(details.playoffs.isEmpty)
        #expect(details.draft.isEmpty)
        #expect(details.rivalries.highlights.isEmpty)
        #expect(details.streaks.isEmpty == false)
        #expect(details.seasons.count == 1)
    }
}

// MARK: - Fixtures used only here

extension DraftPickGrade {
    static let sampleSteal = DraftPickGrade(
        playerID: "9493", playerName: "Puka Nacua", position: "WR",
        season: 2023, leagueID: "784462448236949504", leagueName: "Dynasty Dads",
        round: 9, pick: 33, draftSlot: 1,
        points: 308, expectedPoints: 42, surplus: 266
    )

    /// Sleeper recorded no slot and no name for this pick — both happen.
    static let sampleNoSlot = DraftPickGrade(
        playerID: "0", playerName: nil, position: nil,
        season: 2023, leagueID: "784462448236949504", leagueName: "Dynasty Dads",
        round: 9, pick: 33, draftSlot: nil,
        points: 12, expectedPoints: 42, surplus: -30
    )
}
