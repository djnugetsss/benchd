import Foundation

/// Fixtures for previews and tests.
///
/// Every `#Preview` in this feature draws from here, so the profile can be designed
/// and reviewed without a network, a database, or a connected Sleeper account. The
/// numbers are taken from a real payload the edge function produced for a synthetic
/// three-season career, so the shapes on screen are shapes the server actually emits.
///
/// Built with the memberwise initializers on purpose rather than decoded from a JSON
/// string: a change to the payload types then breaks this file at compile time, which
/// is exactly when it should be noticed. The tests take the opposite approach and
/// decode real server JSON — see `CareerDetailsDecodingTests`.
extension SleeperAccount {
    static let sample = SleeperAccount(
        id: UUID(),
        profileID: UUID(),
        sleeperUserID: "894752173651697664",
        username: "anshhmehta",
        displayName: "Ansh Mehta",
        avatar: nil,
        lastSyncedAt: .now,
        syncStatus: .synced,
        syncError: nil,
        createdAt: .now,
        updatedAt: .now
    )
}

// MARK: - Career stats

extension CareerStats {
    /// A three-season career with a title, a nemesis, and a draft worth talking about.
    static let sample = CareerStats(
        sleeperAccountID: UUID(),
        wins: 33,
        losses: 13,
        ties: 0,
        championships: 1,
        seasons: 3,
        leaguesCount: 3,
        pointsFor: 3678.70,
        pointsAgainst: 3216.00,
        details: .sample,
        computedAt: .now
    )

    /// Someone one month into their first season: no titles, no draft grades yet, no
    /// rivalry that has reached four meetings. The page has to hold up like this.
    static let sampleFirstSeason = CareerStats(
        sleeperAccountID: UUID(),
        wins: 3,
        losses: 1,
        ties: 0,
        championships: 0,
        seasons: 1,
        leaguesCount: 1,
        pointsFor: 482.60,
        pointsAgainst: 441.20,
        details: .sampleFirstSeason,
        computedAt: .now
    )

    /// A row whose details could not be read, and every row computed before the
    /// details existed. The profile must still show its headline numbers.
    static let sampleWithoutDetails = CareerStats(
        sleeperAccountID: UUID(),
        wins: 7,
        losses: 7,
        ties: 0,
        championships: 0,
        seasons: 5,
        leaguesCount: 6,
        pointsFor: 1953.28,
        pointsAgainst: 1741.74,
        details: .empty,
        computedAt: .now
    )

    /// Connected, synced, and genuinely empty — a Sleeper account that has never
    /// joined a league. The page owes them a sentence, not a row of zeroes.
    static let sampleNoLeagues = CareerStats(
        sleeperAccountID: UUID(),
        wins: 0, losses: 0, ties: 0, championships: 0,
        seasons: 0, leaguesCount: 0, pointsFor: 0, pointsAgainst: 0,
        details: CareerDetails(
            version: 1, regularSeason: .empty, playoffs: .empty, streaks: .empty,
            seasons: [], bestSeason: nil, worstSeason: nil, draft: .empty,
            rivalries: .empty, facts: []
        ),
        computedAt: .now
    )

    /// Never won a title, and a losing record. Checks that nothing accents a zero.
    static let sampleWinless = CareerStats(
        sleeperAccountID: UUID(),
        wins: 12,
        losses: 30,
        ties: 1,
        championships: 0,
        seasons: 3,
        leaguesCount: 2,
        pointsFor: 4120.40,
        pointsAgainst: 4788.95,
        details: .sample,
        computedAt: .now
    )
}

// MARK: - Details

extension CareerDetails {
    static let sample = CareerDetails(
        version: 1,
        regularSeason: CareerRecord(
            wins: 33, losses: 13, ties: 0, games: 46,
            winPercentage: 0.72, pointsFor: 3678.70, pointsAgainst: 3216.00,
            pointsPerGame: 114.96
        ),
        playoffs: PlayoffRecord(
            wins: 2, losses: 1, games: 3, winPercentage: 0.67,
            appearances: 2, championships: 1, runnerUps: 1, finals: 2
        ),
        streaks: CareerStreaks(
            longestWin: CareerStreak(
                length: 9, leagueID: "784462448236949504", leagueName: "Dynasty Dads",
                season: 2023, startWeek: 1, endWeek: 9
            ),
            longestLoss: CareerStreak(
                length: 3, leagueID: "784462448236949504", leagueName: "Dynasty Dads",
                season: 2023, startWeek: 10, endWeek: 13
            )
        ),
        seasons: [.sampleMedian, .sampleChampionship, .sampleInProgress],
        bestSeason: .sampleChampionship,
        worstSeason: .sampleMedian,
        draft: DraftGrades(
            bestPicks: [
                DraftPickGrade(
                    playerID: "9493", playerName: "Puka Nacua", position: "WR",
                    season: 2023, leagueID: "784462448236949504", leagueName: "Dynasty Dads",
                    round: 9, pick: 33, draftSlot: 1,
                    points: 308, expectedPoints: 42, surplus: 266
                ),
                DraftPickGrade(
                    playerID: "6794", playerName: "Justin Jefferson", position: "WR",
                    season: 2022, leagueID: "917461823049281536", leagueName: "Work League",
                    round: 3, pick: 9, draftSlot: 1,
                    points: 341, expectedPoints: 216, surplus: 125
                ),
                DraftPickGrade(
                    playerID: "4199", playerName: "Dalton Schultz", position: "TE",
                    season: 2022, leagueID: "917461823049281536", leagueName: "Work League",
                    round: 11, pick: 41, draftSlot: 1,
                    points: 112, expectedPoints: 24, surplus: 88
                ),
            ],
            worstPicks: [
                DraftPickGrade(
                    playerID: "4035", playerName: "Jonathan Taylor", position: "RB",
                    season: 2023, leagueID: "784462448236949504", leagueName: "Dynasty Dads",
                    round: 1, pick: 1, draftSlot: 1,
                    points: 7, expectedPoints: 378, surplus: -371
                ),
                DraftPickGrade(
                    playerID: "5967", playerName: "Gus Edwards", position: "RB",
                    season: 2022, leagueID: "917461823049281536", leagueName: "Work League",
                    round: 4, pick: 13, draftSlot: 1,
                    points: 0, expectedPoints: 184, surplus: -184
                ),
                DraftPickGrade(
                    playerID: "6813", playerName: "Tony Pollard", position: "RB",
                    season: 2023, leagueID: "784462448236949504", leagueName: "Dynasty Dads",
                    round: 6, pick: 21, draftSlot: 1,
                    points: 22, expectedPoints: 121, surplus: -99
                ),
            ],
            scoredPicks: 27,
            leaguesMissingDraftData: 1
        ),
        rivalries: RivalrySummary(
            threshold: 4,
            all: [.sampleMostPlayed, .sampleBeaten, .sampleNemesis],
            mostPlayed: .sampleMostPlayed,
            best: .sampleMostPlayed,
            worst: .sampleNemesis
        ),
        facts: [
            CareerFact(
                key: CareerFact.Key.seasonsPlayed, label: "Seasons played", value: 3,
                unit: .seasons, season: nil, week: nil, leagueName: nil,
                opponent: nil, margin: nil
            ),
            CareerFact(
                key: CareerFact.Key.highestWeek, label: "Highest week ever", value: 148.62,
                unit: .points, season: 2023, week: 15, leagueName: "Dynasty Dads",
                opponent: "Dana Mode", margin: nil
            ),
            CareerFact(
                key: CareerFact.Key.closestWin, label: "Closest win", value: 12.30,
                unit: .points, season: 2023, week: 16, leagueName: "Dynasty Dads",
                opponent: "Priya FC", margin: 12.30
            ),
            CareerFact(
                key: CareerFact.Key.biggestWin, label: "Biggest blowout", value: 62.44,
                unit: .points, season: 2022, week: 7, leagueName: "Work League",
                opponent: "Omar United", margin: 62.44
            ),
            CareerFact(
                key: CareerFact.Key.championships, label: "Championships", value: 1,
                unit: .count, season: nil, week: nil, leagueName: nil,
                opponent: nil, margin: nil
            ),
            CareerFact(
                key: CareerFact.Key.longestWinStreak, label: "Longest win streak", value: 9,
                unit: .games, season: 2023, week: nil, leagueName: "Dynasty Dads",
                opponent: nil, margin: nil
            ),
            CareerFact(
                key: CareerFact.Key.pointsFor, label: "Points scored, all time",
                value: 3678.70, unit: .points, season: nil, week: nil,
                leagueName: nil, opponent: nil, margin: nil
            ),
        ]
    )

    /// One unfinished season and nothing else: no playoffs, no draft grades, no
    /// rivalry that qualifies yet.
    static let sampleFirstSeason = CareerDetails(
        version: 1,
        regularSeason: CareerRecord(
            wins: 3, losses: 1, ties: 0, games: 4,
            winPercentage: 0.75, pointsFor: 482.60, pointsAgainst: 441.20,
            pointsPerGame: 120.65
        ),
        playoffs: .empty,
        streaks: CareerStreaks(
            longestWin: CareerStreak(
                length: 3, leagueID: "1131742819283746816", leagueName: "Dynasty Dads",
                season: 2026, startWeek: 1, endWeek: 3
            ),
            longestLoss: nil
        ),
        seasons: [.sampleInProgress],
        bestSeason: nil,
        worstSeason: nil,
        draft: DraftGrades(
            bestPicks: [], worstPicks: [], scoredPicks: 0, leaguesMissingDraftData: 0
        ),
        rivalries: .empty,
        facts: [
            CareerFact(
                key: CareerFact.Key.highestWeek, label: "Highest week ever", value: 133.28,
                unit: .points, season: 2026, week: 1, leagueName: "Dynasty Dads",
                opponent: "Dana Mode", margin: nil
            ),
            CareerFact(
                key: CareerFact.Key.closestWin, label: "Closest win", value: 4.12,
                unit: .points, season: 2026, week: 3, leagueName: "Dynasty Dads",
                opponent: "Omar United", margin: 4.12
            ),
        ]
    )
}

// MARK: - Seasons

extension SeasonSummary {
    /// The title year.
    static let sampleChampionship = SeasonSummary(
        season: 2023, leagueID: "784462448236949504", leagueName: "Dynasty Dads",
        rosterID: 3, teamName: "Bench Mob",
        wins: 9, losses: 5, ties: 0, games: 14, winPercentage: 0.64,
        pointsFor: 1747.48, pointsAgainst: 1407.00, pointsPerGame: 124.82,
        playoffPointsFor: 279.82, highWeek: 148.62, lowWeek: 96.40,
        regularWeeks: 14, weeksPlayed: 16, finishRank: 1,
        playoffWins: 2, playoffLosses: 0, madePlayoffs: true,
        champion: true, runnerUp: false, inProgress: false,
        medianScoring: false, recordSource: .matchups
    )

    /// A median-scoring league: 28 results from 14 weeks, which is why the footnote
    /// under the timeline exists.
    static let sampleMedian = SeasonSummary(
        season: 2022, leagueID: "917461823049281536", leagueName: "Work League",
        rosterID: 3, teamName: "Bench Mob",
        wins: 20, losses: 8, ties: 0, games: 28, winPercentage: 0.71,
        pointsFor: 1598.02, pointsAgainst: 1407.00, pointsPerGame: 114.14,
        playoffPointsFor: 0, highWeek: 118.66, lowWeek: 88.40,
        regularWeeks: 14, weeksPlayed: 14, finishRank: 5,
        playoffWins: 0, playoffLosses: 1, madePlayoffs: true,
        champion: false, runnerUp: true, inProgress: false,
        medianScoring: true, recordSource: .matchups
    )

    /// Four weeks into this season.
    static let sampleInProgress = SeasonSummary(
        season: 2026, leagueID: "1131742819283746816", leagueName: "Dynasty Dads",
        rosterID: 7, teamName: "Bench Mob",
        wins: 4, losses: 0, ties: 0, games: 4, winPercentage: 1.0,
        pointsFor: 533.12, pointsAgainst: 402.00, pointsPerGame: 133.28,
        playoffPointsFor: 0, highWeek: 141.20, lowWeek: 121.44,
        regularWeeks: 4, weeksPlayed: 4, finishRank: nil,
        playoffWins: 0, playoffLosses: 0, madePlayoffs: false,
        champion: false, runnerUp: false, inProgress: true,
        medianScoring: false, recordSource: .matchups
    )

    /// A league joined before its season started — nothing played, and its record
    /// taken from Sleeper's roster totals rather than from weeks.
    static let sampleUnplayed = SeasonSummary(
        season: 2026, leagueID: "1131742819283746817", leagueName: "The New One",
        rosterID: 2, teamName: nil,
        wins: 0, losses: 0, ties: 0, games: 0, winPercentage: nil,
        pointsFor: 0, pointsAgainst: 0, pointsPerGame: nil,
        playoffPointsFor: 0, highWeek: nil, lowWeek: nil,
        regularWeeks: 0, weeksPlayed: 0, finishRank: nil,
        playoffWins: 0, playoffLosses: 0, madePlayoffs: false,
        champion: false, runnerUp: false, inProgress: true,
        medianScoring: false, recordSource: .rosterTotals
    )
}

// MARK: - Rivalries

extension Rivalry {
    /// Played most, and beaten most: one person usually holds both roles.
    static let sampleMostPlayed = Rivalry(
        opponentKey: "111111111111111111", opponentUserID: "111111111111111111",
        name: "Dana Mode", games: 14, wins: 12, losses: 2, ties: 0,
        winPercentage: 0.86, pointsFor: 1688.40, pointsAgainst: 1407.00,
        seasons: [2022, 2023, 2026]
    )

    static let sampleBeaten = Rivalry(
        opponentKey: "222222222222222222", opponentUserID: "222222222222222222",
        name: "Omar United", games: 11, wins: 9, losses: 2, ties: 0,
        winPercentage: 0.82, pointsFor: 1288.10, pointsAgainst: 1105.50,
        seasons: [2022, 2023]
    )

    /// The one who wins.
    static let sampleNemesis = Rivalry(
        opponentKey: "333333333333333333", opponentUserID: "333333333333333333",
        name: "Priya FC", games: 9, wins: 4, losses: 5, ties: 0,
        winPercentage: 0.44, pointsFor: 1002.80, pointsAgainst: 1061.25,
        seasons: [2022, 2023, 2026]
    )
}
