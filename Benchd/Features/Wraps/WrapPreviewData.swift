import Foundation

/// Fixtures for previews and tests.
///
/// The numbers are a real `weekly_wrap` payload, run against a seeded database:
/// a manager who put up the top score in one league and lost by four tenths of a
/// point in another, which is the week every fantasy player has had.
///
/// Built with the memberwise initializers rather than decoded from JSON, so a
/// change to the payload types breaks this file at compile time. The tests take
/// the other approach and decode the server's own JSON — see `WeeklyWrapTests`.
extension WeeklyWrap {
    static let sample = WeeklyWrap(
        season: 2026,
        week: 5,
        record: WrapRecord(wins: 1, losses: 1, ties: 0),
        pointsFor: 245.02,
        pointsAgainst: 227.20,
        leagues: [
            WrapLeagueResult(
                leagueID: "784462448236949504",
                leagueName: "Dynasty Dads",
                teamName: "Bench Mob",
                points: 148.62,
                opponentName: "Dana Mode",
                opponentPoints: 130.40,
                result: .win,
                margin: 18.22,
                leagueRank: 1,
                teams: 12,
                leagueHigh: true
            ),
            WrapLeagueResult(
                leagueID: "917461823049281536",
                leagueName: "Work League",
                teamName: "Bench Mob",
                points: 96.40,
                opponentName: "Priya FC",
                opponentPoints: 96.80,
                result: .loss,
                margin: -0.40,
                leagueRank: 9,
                teams: 10,
                leagueHigh: false
            ),
        ],
        performers: [
            WrapPerformer(
                playerID: "9493", name: "Puka Nacua", position: "WR",
                team: "LAR", points: 34.20, leagueName: "Dynasty Dads"
            ),
            WrapPerformer(
                playerID: "5849", name: "Josh Allen", position: "QB",
                team: "BUF", points: 28.60, leagueName: "Dynasty Dads"
            ),
            WrapPerformer(
                playerID: "8138", name: "Bijan Robinson", position: "RB",
                team: "ATL", points: 24.40, leagueName: "Dynasty Dads"
            ),
        ],
        highlight: WrapHighlight(
            kind: WrapHighlight.Kind.leagueHigh,
            headline: "Top score in the league",
            value: 148.62,
            caption: "Dynasty Dads"
        )
    )

    /// One league, and the loss nobody gets over. The card has to be worth
    /// posting on a bad week too — this is the one people screenshot to complain.
    static let sampleSingleLeague = WeeklyWrap(
        season: 2026,
        week: 5,
        record: WrapRecord(wins: 0, losses: 1, ties: 0),
        pointsFor: 96.40,
        pointsAgainst: 96.80,
        leagues: [
            WrapLeagueResult(
                leagueID: "917461823049281536",
                leagueName: "Work League",
                teamName: "Bench Mob",
                points: 96.40,
                opponentName: "Priya FC",
                opponentPoints: 96.80,
                result: .loss,
                margin: -0.40,
                leagueRank: 9,
                teams: 10,
                leagueHigh: false
            ),
        ],
        performers: [
            WrapPerformer(
                playerID: "9493", name: "Puka Nacua", position: "WR",
                team: "LAR", points: 31.80, leagueName: "Work League"
            ),
            WrapPerformer(
                playerID: "7600", name: "Rachaad White", position: "RB",
                team: "TB", points: 12.10, leagueName: "Work League"
            ),
            WrapPerformer(
                playerID: "4199", name: "Dalton Schultz", position: "TE",
                team: "HOU", points: 8.40, leagueName: "Work League"
            ),
        ],
        highlight: WrapHighlight(
            kind: WrapHighlight.Kind.closeLoss,
            headline: "Lost by 0.4",
            value: 0.40,
            caption: "Work League"
        )
    )

    /// A long name, a long league name, and a three-league week: the widths that
    /// break a layout if it was only ever designed against short fixtures.
    static let sampleWide = WeeklyWrap(
        season: 2026,
        week: 12,
        record: WrapRecord(wins: 2, losses: 0, ties: 1),
        pointsFor: 401.88,
        pointsAgainst: 355.10,
        leagues: [
            WrapLeagueResult(
                leagueID: "1", leagueName: "The Wednesday Night Bootleg League",
                teamName: "Bench Mob", points: 151.44,
                opponentName: "Christian's Championship Contenders",
                opponentPoints: 120.10, result: .win, margin: 31.34,
                leagueRank: 1, teams: 12, leagueHigh: true
            ),
            WrapLeagueResult(
                leagueID: "2", leagueName: "Work League", teamName: "Bench Mob",
                points: 132.22, opponentName: "Priya FC", opponentPoints: 115.00,
                result: .win, margin: 17.22, leagueRank: 2, teams: 10, leagueHigh: false
            ),
            WrapLeagueResult(
                leagueID: "3", leagueName: "Dynasty Dads", teamName: "Bench Mob",
                points: 118.22, opponentName: "Dana Mode", opponentPoints: 118.22,
                result: .tie, margin: 0, leagueRank: 4, teams: 12, leagueHigh: false
            ),
        ],
        performers: [
            WrapPerformer(
                playerID: "1", name: "Amon-Ra St. Brown", position: "WR",
                team: "DET", points: 41.70, leagueName: "The Wednesday Night Bootleg League"
            ),
            WrapPerformer(
                playerID: "2", name: "Marvin Harrison Jr.", position: "WR",
                team: "ARI", points: 29.90, leagueName: "Work League"
            ),
            WrapPerformer(
                playerID: "3", name: "Jonathan Taylor", position: "RB",
                team: "IND", points: 26.10, leagueName: "Dynasty Dads"
            ),
        ],
        // A tie means this is not a perfect week, so the database would fall
        // through to the weekly rank. Fixtures have to be things the server
        // could actually say.
        highlight: WrapHighlight(
            kind: WrapHighlight.Kind.rank,
            headline: "1st of 12 this week",
            value: 1,
            caption: "The Wednesday Night Bootleg League"
        )
    )

    /// Four weeks of history, newest first, for the Wraps tab's strip.
    static let sampleHistory: [WeeklyWrap] = [
        .sample,
        WeeklyWrap(
            season: 2026, week: 4,
            record: WrapRecord(wins: 1, losses: 1, ties: 0),
            pointsFor: 243.52, pointsAgainst: 243.10,
            leagues: [
                WrapLeagueResult(
                    leagueID: "917461823049281536", leagueName: "Work League",
                    teamName: "Bench Mob", points: 131.44, opponentName: "Priya FC",
                    opponentPoints: 101.90, result: .win, margin: 29.54,
                    leagueRank: 1, teams: 10, leagueHigh: false
                ),
                WrapLeagueResult(
                    leagueID: "784462448236949504", leagueName: "Dynasty Dads",
                    teamName: "Bench Mob", points: 112.08, opponentName: "Dana Mode",
                    opponentPoints: 141.20, result: .loss, margin: -29.12,
                    leagueRank: 6, teams: 12, leagueHigh: false
                ),
            ],
            performers: [
                WrapPerformer(playerID: "9493", name: "Puka Nacua", position: "WR",
                              team: "LAR", points: 26.60, leagueName: "Work League"),
                WrapPerformer(playerID: "5849", name: "Josh Allen", position: "QB",
                              team: "BUF", points: 22.10, leagueName: "Dynasty Dads"),
                WrapPerformer(playerID: "9493b", name: "Jaxon Smith-Njigba", position: "WR",
                              team: "SEA", points: 19.40, leagueName: "Dynasty Dads"),
            ],
            highlight: WrapHighlight(
                kind: WrapHighlight.Kind.points, headline: "243.5 points",
                value: 243.52, caption: nil
            )
        ),
        WeeklyWrap(
            season: 2026, week: 3,
            record: WrapRecord(wins: 2, losses: 0, ties: 0),
            pointsFor: 262.80, pointsAgainst: 218.40,
            leagues: [
                WrapLeagueResult(
                    leagueID: "784462448236949504", leagueName: "Dynasty Dads",
                    teamName: "Bench Mob", points: 118.40, opponentName: "Dana Mode",
                    opponentPoints: 118.00, result: .win, margin: 0.40,
                    leagueRank: 5, teams: 12, leagueHigh: false
                ),
            ],
            performers: [
                WrapPerformer(playerID: "9493", name: "Puka Nacua", position: "WR",
                              team: "LAR", points: 29.40, leagueName: "Dynasty Dads"),
                WrapPerformer(playerID: "5849", name: "Josh Allen", position: "QB",
                              team: "BUF", points: 21.00, leagueName: "Dynasty Dads"),
                WrapPerformer(playerID: "8138", name: "Bijan Robinson", position: "RB",
                              team: "ATL", points: 17.80, leagueName: "Dynasty Dads"),
            ],
            highlight: WrapHighlight(
                kind: WrapHighlight.Kind.closeWin, headline: "Won by 0.4",
                value: 0.40, caption: "Dynasty Dads"
            )
        ),
        .sampleWide,
    ]
}
