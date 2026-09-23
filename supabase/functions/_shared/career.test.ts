/**
 * Tests for the career stats computation.
 *
 * The fixtures are built to look like real Sleeper payloads: 10- and 6-team
 * leagues, a rotating schedule, two-decimal scores, weeks that have not been
 * played, bracket entries with `{ w: 3 }` placeholders in them. The builders at
 * the bottom exist so each test can state the one situation it is about.
 */

import { assert, assertAlmostEquals, assertEquals } from "jsr:@std/assert@1";
import {
  type BracketEntry,
  type CareerInput,
  computeCareerStats,
  type DraftRow,
  lastCountedWeek,
  type LeagueBundle,
  type MatchupRow,
  type MemberRow,
  type PickRow,
  playoffWeekStart,
  userRosterIds,
} from "./career.ts";

// The account under test, plus the crew it plays against. Real Sleeper ids are
// 18-digit strings and rivalries are keyed on them, so the fixtures use ids
// shaped like the real thing rather than "user1".
const ME = "894752173651697664";
const DANA = "111111111111111111";
const OMAR = "222222222222222222";
const PRIYA = "333333333333333333";
const LEE = "444444444444444444";
const SAM = "555555555555555555";

// ---------------------------------------------------------------------------
// Nothing to compute
// ---------------------------------------------------------------------------

Deno.test("an account with no leagues produces zeroes, not NaN", () => {
  const stats = computeCareerStats({ sleeper_user_id: ME, leagues: [] });

  assertEquals(stats.wins, 0);
  assertEquals(stats.losses, 0);
  assertEquals(stats.seasons, 0);
  assertEquals(stats.leagues_count, 0);
  assertEquals(stats.points_for, 0);
  assertEquals(stats.details.regular_season.win_pct, null);
  assertEquals(stats.details.regular_season.points_per_game, null);
  assertEquals(stats.details.best_season, null);
  assertEquals(stats.details.streaks.longest_win, null);
  assertEquals(stats.details.rivalries.most_played, null);
  assertEquals(stats.details.draft.best_picks, []);
  assertEquals(stats.details.facts, []);
});

Deno.test("a league the user was never in does not count", () => {
  // The sync follows previous_league_id chains into seasons this account was not
  // a member of. Those leagues are stored, and must contribute nothing.
  const theirs = bundle({
    id: "2019_before_me",
    season: 2019,
    teams: [team(1, DANA), team(2, OMAR)],
    games: [game(1, 1, 120.5, 2, 99.4)],
  });

  const stats = computeCareerStats({ sleeper_user_id: ME, leagues: [theirs] });

  assertEquals(stats.seasons, 0);
  assertEquals(stats.leagues_count, 0);
  assertEquals(stats.details.seasons, []);
});

// ---------------------------------------------------------------------------
// The regular season
// ---------------------------------------------------------------------------

Deno.test("regular season record, win %, and points add up across seasons", () => {
  const stats = computeCareerStats(fullCareer());

  // 2023: won weeks 1–8, lost 9–14. 2024: won weeks 1–3, lost week 4.
  assertEquals(stats.wins, 11);
  assertEquals(stats.losses, 7);
  assertEquals(stats.ties, 0);
  assertEquals(stats.details.regular_season.games, 18);
  assertEquals(stats.details.regular_season.win_pct, 0.61);

  // 2023: 8 × 120.44 + 6 × 90.12. 2024: 3 × 130.00 + 1 × 80.00.
  assertAlmostEquals(stats.points_for, 1504.24 + 470, 0.001);
  // Every opponent the user faced scored 100.50 in 2023 and 100.00 in 2024.
  assertAlmostEquals(stats.points_against, 14 * 100.5 + 4 * 100, 0.001);

  assertEquals(stats.seasons, 2);
  assertEquals(stats.leagues_count, 2);
});

Deno.test("per-season rows carry the timeline, oldest first", () => {
  const stats = computeCareerStats(fullCareer());
  const [first, second] = stats.details.seasons;

  assertEquals(stats.details.seasons.length, 2);

  assertEquals(first.season, 2023);
  assertEquals(first.league_name, "Dynasty Dads");
  assertEquals(first.team_name, "Bench Mob");
  assertEquals([first.wins, first.losses, first.ties], [8, 6, 0]);
  assertEquals(first.games, 14);
  assertEquals(first.weeks_played, 16); // 14 regular weeks plus two playoff weeks
  assertEquals(first.high_week, 148.6); // set in a playoff week, not a regular one
  assertEquals(first.low_week, 90.12);
  assertEquals(first.champion, true);
  assertEquals(first.in_progress, false);
  assertEquals(first.median_scoring, false);
  assertAlmostEquals(first.playoff_points_for, 148.6 + 131.2, 0.001);
  assertEquals(first.points_per_game, 107.45);

  assertEquals(second.season, 2024);
  assertEquals([second.wins, second.losses], [3, 1]);
  assertEquals(second.in_progress, true);
  assertEquals(second.champion, false);
  // The roster number changed when the league rolled over. Same person.
  assertEquals(first.roster_id, 3);
  assertEquals(second.roster_id, 5);
});

Deno.test("a tie is half a win and breaks a streak without starting one", () => {
  const stats = computeCareerStats({
    sleeper_user_id: ME,
    leagues: [bundle({
      teams: [team(1, ME), team(2, DANA)],
      games: [
        game(1, 1, 110.0, 2, 90.0),
        game(2, 1, 105.5, 2, 105.5), // ties happen, in half-point leagues most often
        game(3, 1, 118.0, 2, 92.0),
      ],
    })],
  });

  assertEquals([stats.wins, stats.losses, stats.ties], [2, 0, 1]);
  assertEquals(stats.details.regular_season.win_pct, 0.83);
  // Two wins either side of a tie is not a three-game streak.
  assertEquals(stats.details.streaks.longest_win?.length, 1);
});

Deno.test("a commissioner's custom_points overrides the computed score", () => {
  const stats = computeCareerStats({
    sleeper_user_id: ME,
    leagues: [bundle({
      teams: [team(1, ME), team(2, DANA)],
      games: [game(1, 1, 88.0, 2, 120.0)],
      custom: [{ week: 1, roster: 1, points: 130.0 }],
    })],
  });

  // 88 would be a loss. The override to 130 is the score of record.
  assertEquals([stats.wins, stats.losses], [1, 0]);
  assertEquals(stats.points_for, 130);
});

// ---------------------------------------------------------------------------
// Unfinished seasons
// ---------------------------------------------------------------------------

Deno.test("weeks that have not been played are not losses", () => {
  // Sleeper answers for every week of an in-season league, including ones that
  // have not happened. Counted naively, the rest of the year is a losing streak.
  const stats = computeCareerStats({
    sleeper_user_id: ME,
    leagues: [bundle({
      season: 2026,
      status: "in_season",
      settings: { leg: 3, playoff_week_start: 15 },
      teams: [team(1, ME), team(2, DANA)],
      games: [
        game(1, 1, 121.4, 2, 98.2),
        game(2, 1, 130.8, 2, 110.6),
        game(3, 1, 42.1, 2, 12.0), // in progress: Thursday night only
        game(4, 1, 0, 2, 0), // not played
        game(5, 1, 0, 2, 0),
      ],
    })],
  });

  assertEquals([stats.wins, stats.losses, stats.ties], [2, 0, 0]);
  assertEquals(stats.details.seasons[0].weeks_played, 2);
  // Week 3 is excluded as well: a partial score is not a result.
  assertAlmostEquals(stats.points_for, 121.4 + 130.8, 0.001);
});

Deno.test("an all-zero week is skipped even when the league reports no leg", () => {
  const stats = computeCareerStats({
    sleeper_user_id: ME,
    leagues: [bundle({
      status: "in_season",
      settings: { playoff_week_start: 15 },
      teams: [team(1, ME), team(2, DANA)],
      games: [game(1, 1, 101.2, 2, 99.9), game(2, 1, 0, 2, 0)],
    })],
  });

  assertEquals([stats.wins, stats.losses], [1, 0]);
  assertEquals(stats.details.seasons[0].weeks_played, 1);
});

Deno.test("a real zero-point week still counts as the loss it was", () => {
  // Forgetting to set a lineup is not missing data. The week is judged across
  // both sides, so the opponent's points prove it happened.
  const stats = computeCareerStats({
    sleeper_user_id: ME,
    leagues: [bundle({
      teams: [team(1, ME), team(2, DANA)],
      games: [game(1, 1, 0, 2, 96.4)],
    })],
  });

  assertEquals([stats.wins, stats.losses], [0, 1]);
  assertEquals(stats.details.seasons[0].low_week, 0);
});

Deno.test("a season whose weeks have not landed falls back to Sleeper's totals", () => {
  // The sync writes rosters before matchups. Between the two — a time budget cut
  // short, a killed instance — the season exists with no weeks in it. Sleeper's
  // own roster totals are a better answer than a phantom 0–0.
  const season = bundle({
    teams: [team(1, ME, "Bench Mob"), team(2, DANA)],
    games: [],
  });
  season.members[0] = {
    ...season.members[0],
    wins: 9,
    losses: 4,
    ties: 1,
    fpts: 1642.88,
    fpts_against: 1501.2,
  };

  const stats = computeCareerStats({ sleeper_user_id: ME, leagues: [season] });
  const row = stats.details.seasons[0];

  assertEquals([stats.wins, stats.losses, stats.ties], [9, 4, 1]);
  assertEquals(stats.points_for, 1642.88);
  assertEquals(stats.points_against, 1501.2);
  assertEquals(row.record_source, "roster_totals");
  // The week-level numbers are honestly empty rather than invented.
  assertEquals(row.weeks_played, 0);
  assertEquals(row.high_week, null);
  assertEquals(row.points_per_game, null);
  assertEquals(stats.details.streaks.longest_win, null);
});

Deno.test("points per game divides by regular season weeks, not playoff ones", () => {
  const stats = computeCareerStats(fullCareer());

  // 18 regular season weeks across the two seasons, not the 20 weeks played.
  assertEquals(stats.details.seasons[0].regular_weeks, 14);
  assertEquals(stats.details.seasons[0].weeks_played, 16);
  assertEquals(stats.details.seasons[0].record_source, "matchups");
  assertAlmostEquals(
    stats.details.regular_season.points_per_game ?? 0,
    1974.24 / 18,
    0.01,
  );
});

Deno.test("best and worst season ignore a season still in progress", () => {
  const stats = computeCareerStats(fullCareer());

  // 2024 is 3–1, a .750 pace, but unfinished. 2023 is the only real season.
  assertEquals(stats.details.best_season?.season, 2023);
  assertEquals(stats.details.worst_season?.season, 2023);
});

Deno.test("best and worst season rank by win %, then points", () => {
  const stats = computeCareerStats({
    sleeper_user_id: ME,
    leagues: [
      bundle({
        id: "2022",
        season: 2022,
        teams: [team(1, ME), team(2, DANA)],
        games: [game(1, 1, 150.0, 2, 90.0), game(2, 1, 140.0, 2, 95.0)],
      }),
      bundle({
        id: "2023",
        season: 2023,
        teams: [team(1, ME), team(2, DANA)],
        games: [game(1, 1, 80.0, 2, 90.0), game(2, 1, 70.0, 2, 95.0)],
      }),
    ],
  });

  assertEquals(stats.details.best_season?.season, 2022);
  assertEquals(stats.details.worst_season?.season, 2023);
});

// ---------------------------------------------------------------------------
// Median scoring
// ---------------------------------------------------------------------------

Deno.test("a median-scoring league settles two results a week", () => {
  // league_average_match: every team also plays the league median, so a
  // four-week season produces eight results.
  const stats = computeCareerStats({
    sleeper_user_id: ME,
    leagues: [bundle({
      settings: { league_average_match: 1, playoff_week_start: 15 },
      teams: [team(1, ME), team(2, DANA), team(3, OMAR), team(4, PRIYA)],
      games: [
        // Won the matchup, and 120.50 is over the week's median of 99.50.
        game(1, 1, 120.5, 2, 99.0),
        game(1, 3, 100.0, 4, 95.0),
        // Lost the matchup, still cleared the median of 97.50.
        game(2, 1, 105.0, 2, 118.0),
        game(2, 3, 90.0, 4, 80.0),
        // Lost both: 70.00 against 101.00, and a median of 98.50.
        game(3, 1, 70.0, 2, 101.0),
        game(3, 3, 99.0, 4, 98.0),
        // Tied both: three teams on 100.00 puts the median on 100.00 too.
        game(4, 1, 100.0, 2, 100.0),
        game(4, 3, 100.0, 4, 80.0),
      ],
    })],
  });

  // Matchups: W L L T. Medians: W W L T.
  assertEquals([stats.wins, stats.losses, stats.ties], [3, 3, 2]);
  assertEquals(stats.details.regular_season.games, 8);
  assertEquals(stats.details.seasons[0].median_scoring, true);
  assertEquals(stats.details.regular_season.win_pct, 0.5);

  // Points against stays head-to-head. The median is a threshold, not a team,
  // and adding it would invent points nobody scored.
  assertAlmostEquals(stats.points_against, 99 + 118 + 101 + 100, 0.001);
  assertAlmostEquals(stats.points_for, 120.5 + 105 + 70 + 100, 0.001);
});

// ---------------------------------------------------------------------------
// Playoffs
// ---------------------------------------------------------------------------

Deno.test("playoff record and championship come from the winners bracket", () => {
  const stats = computeCareerStats(fullCareer());

  assertEquals(stats.championships, 1);
  assertEquals(stats.details.playoffs.championships, 1);
  assertEquals(stats.details.playoffs.runner_ups, 0);
  assertEquals(stats.details.playoffs.finals, 1);
  assertEquals(stats.details.playoffs.appearances, 1);
  // A semi-final and a final, both won. The fifth-place game played in the same
  // week by two other teams is not part of anyone's playoff record.
  assertEquals([stats.details.playoffs.wins, stats.details.playoffs.losses], [2, 0]);
  assertEquals(stats.details.playoffs.win_pct, 1);
  assertEquals(stats.details.seasons[0].playoff_wins, 2);
  assertEquals(stats.details.seasons[0].playoff_losses, 0);
});

Deno.test("consolation games in playoff weeks are not a playoff record", () => {
  // The user missed the playoffs and played two consolation games in weeks
  // 15–16. Both are in `matchups`; neither is in the winners bracket.
  const stats = computeCareerStats({
    sleeper_user_id: ME,
    leagues: [bundle({
      teams: [team(1, ME, "Bench Mob", 8), team(2, DANA), team(3, OMAR), team(4, PRIYA)],
      settings: { playoff_week_start: 15, playoff_teams: 4 },
      games: [
        game(14, 1, 88.0, 2, 120.0),
        game(15, 1, 101.0, 2, 95.0), // consolation
        game(16, 1, 99.0, 2, 140.0), // consolation
      ],
      bracket: [
        { r: 1, m: 1, t1: 3, t2: 4, w: 3, l: 4 },
        { r: 2, m: 2, t1: { w: 1 }, t2: 2, w: 3, l: 2, p: 1 },
      ],
    })],
  });

  assertEquals([stats.details.playoffs.wins, stats.details.playoffs.losses], [0, 0]);
  assertEquals(stats.details.playoffs.appearances, 0);
  assertEquals(stats.championships, 0);
  // The weeks still happened: they count for points, and week 14 for the record.
  assertEquals([stats.wins, stats.losses], [0, 1]);
  assertEquals(stats.details.seasons[0].weeks_played, 3);
});

Deno.test("losing the final is a runner-up, not a championship", () => {
  const stats = computeCareerStats({
    sleeper_user_id: ME,
    leagues: [bundle({
      teams: [team(1, ME, "Bench Mob", 2), team(2, DANA), team(3, OMAR)],
      settings: { playoff_week_start: 15, playoff_teams: 4 },
      games: [game(15, 1, 130.0, 2, 120.0), game(16, 1, 110.0, 3, 140.0)],
      bracket: [
        { r: 1, m: 1, t1: 1, t2: 2, w: 1, l: 2 },
        { r: 2, m: 2, t1: { w: 1 }, t2: 3, w: 3, l: 1, p: 1 },
      ],
    })],
  });

  assertEquals(stats.championships, 0);
  assertEquals(stats.details.playoffs.runner_ups, 1);
  assertEquals(stats.details.playoffs.finals, 1);
  assertEquals([stats.details.playoffs.wins, stats.details.playoffs.losses], [1, 1]);
  assertEquals(stats.details.seasons[0].made_playoffs, true);
});

Deno.test("a bracket that has not been seeded yet is not a playoff exit", () => {
  const stats = computeCareerStats({
    sleeper_user_id: ME,
    leagues: [bundle({
      season: 2026,
      status: "in_season",
      settings: { leg: 5, playoff_week_start: 15 },
      teams: [team(1, ME), team(2, DANA)],
      games: [game(1, 1, 120.0, 2, 90.0)],
      bracket: [],
    })],
  });

  assertEquals(stats.details.playoffs.appearances, 0);
  assertEquals(stats.details.playoffs.games, 0);
  assertEquals(stats.championships, 0);
});

Deno.test("without a stored bracket, finish_rank still yields the title", () => {
  // Leagues synced before winners_bracket landed have finish_rank and nothing
  // else. A championship must not disappear while waiting for the next sync.
  const stats = computeCareerStats({
    sleeper_user_id: ME,
    leagues: [bundle({
      teams: [team(1, ME, "Bench Mob", 1), team(2, DANA)],
      settings: { playoff_week_start: 15, playoff_teams: 6 },
      games: [game(14, 1, 120.0, 2, 90.0)],
      bracket: null,
    })],
  });

  assertEquals(stats.championships, 1);
  assertEquals(stats.details.playoffs.appearances, 1);
  // The round-by-round record is the part that cannot be recovered.
  assertEquals(stats.details.playoffs.games, 0);
});

// ---------------------------------------------------------------------------
// Streaks
// ---------------------------------------------------------------------------

Deno.test("longest win and losing streaks come off one league-season", () => {
  const stats = computeCareerStats(fullCareer());

  assertEquals(stats.details.streaks.longest_win?.length, 8);
  assertEquals(stats.details.streaks.longest_win?.season, 2023);
  assertEquals(stats.details.streaks.longest_win?.start_week, 1);
  assertEquals(stats.details.streaks.longest_win?.end_week, 8);

  assertEquals(stats.details.streaks.longest_loss?.length, 6);
  assertEquals(stats.details.streaks.longest_loss?.start_week, 9);
  assertEquals(stats.details.streaks.longest_loss?.end_week, 14);
});

Deno.test("two leagues in one season do not interleave into a fake streak", () => {
  // Weeks alternate W and L across two leagues. Ordered by week alone that is
  // one six-game run of nothing; per league it is two three-game streaks.
  const wins = bundle({
    id: "league_a",
    name: "Dynasty Dads",
    teams: [team(1, ME), team(2, DANA)],
    games: [
      game(1, 1, 120.0, 2, 90.0),
      game(2, 1, 121.0, 2, 91.0),
      game(3, 1, 122.0, 2, 92.0),
    ],
  });
  const losses = bundle({
    id: "league_b",
    name: "Work League",
    teams: [team(1, ME), team(2, OMAR)],
    games: [
      game(1, 1, 80.0, 2, 130.0),
      game(2, 1, 81.0, 2, 131.0),
      game(3, 1, 82.0, 2, 132.0),
    ],
  });

  const stats = computeCareerStats({ sleeper_user_id: ME, leagues: [wins, losses] });

  assertEquals(stats.details.streaks.longest_win?.length, 3);
  assertEquals(stats.details.streaks.longest_win?.league_name, "Dynasty Dads");
  assertEquals(stats.details.streaks.longest_loss?.length, 3);
  assertEquals(stats.details.streaks.longest_loss?.league_name, "Work League");
  assertEquals([stats.wins, stats.losses], [3, 3]);
});

// ---------------------------------------------------------------------------
// Rivalries
// ---------------------------------------------------------------------------

Deno.test("rivalries need four meetings, and follow the person not the roster", () => {
  // The same crew, two league ids, different roster numbers each season — which
  // is what a Sleeper league looks like after it rolls over.
  const y2023 = bundle({
    id: "riv_2023",
    season: 2023,
    teams: [team(3, ME), team(4, DANA, "Dana's Dynasty"), team(5, OMAR), team(6, PRIYA)],
    games: [
      game(1, 3, 120.0, 4, 100.0),
      game(2, 3, 118.0, 4, 130.0),
      game(3, 3, 111.0, 5, 99.0),
      game(4, 3, 95.0, 6, 140.0),
    ],
  });
  const y2024 = bundle({
    id: "riv_2024",
    season: 2024,
    teams: [team(9, ME), team(1, DANA, "Dana Mode"), team(2, OMAR), team(7, PRIYA)],
    games: [
      game(1, 9, 101.0, 1, 90.0),
      game(2, 9, 99.0, 1, 140.0),
      game(3, 9, 105.0, 2, 120.0),
      game(4, 9, 130.0, 7, 90.0),
    ],
  });

  const stats = computeCareerStats({ sleeper_user_id: ME, leagues: [y2023, y2024] });
  const { all, most_played, best, worst } = stats.details.rivalries;

  // Only Dana has been played four times. Two meetings is a coincidence.
  assertEquals(all.length, 1);
  assertEquals(most_played?.opponent_user_id, DANA);
  assertEquals(most_played?.games, 4);
  assertEquals([most_played?.wins, most_played?.losses], [2, 2]);
  assertEquals(most_played?.seasons, [2023, 2024]);
  // The name tracks the most recent season, because that is the one they use.
  assertEquals(most_played?.name, "Dana Mode");
  assertEquals(best?.opponent_user_id, DANA);
  assertEquals(worst?.opponent_user_id, DANA);
});

Deno.test("the rival beaten most and the rival who wins most are separate", () => {
  const stats = computeCareerStats({
    sleeper_user_id: ME,
    leagues: [bundle({
      teams: [team(1, ME), team(2, OMAR, "Omar's Heroes"), team(3, PRIYA, "Priya FC")],
      games: [
        // 4–0 against Omar.
        game(1, 1, 120.0, 2, 90.0),
        game(2, 1, 121.0, 2, 91.0),
        game(3, 1, 122.0, 2, 92.0),
        game(4, 1, 123.0, 2, 93.0),
        // 1–4 against Priya.
        game(5, 1, 130.0, 3, 90.0),
        game(6, 1, 80.0, 3, 140.0),
        game(7, 1, 81.0, 3, 141.0),
        game(8, 1, 82.0, 3, 142.0),
        game(9, 1, 83.0, 3, 143.0),
      ],
    })],
  });

  const { most_played, best, worst } = stats.details.rivalries;
  assertEquals(most_played?.name, "Priya FC"); // five meetings beats four
  assertEquals(best?.name, "Omar's Heroes");
  assertEquals(best?.wins, 4);
  assertEquals(worst?.name, "Priya FC");
  assertEquals(worst?.losses, 4);
  assertEquals(worst?.win_pct, 0.2);
});

Deno.test("an unmanaged roster is still an opponent, scoped to its league", () => {
  const stats = computeCareerStats({
    sleeper_user_id: ME,
    leagues: [bundle({
      id: "orphans",
      teams: [team(1, ME), team(2, null, "Orphaned Team")],
      games: [
        game(1, 1, 120.0, 2, 90.0),
        game(2, 1, 121.0, 2, 91.0),
        game(3, 1, 122.0, 2, 92.0),
        game(4, 1, 80.0, 2, 130.0),
      ],
    })],
  });

  const rival = stats.details.rivalries.all[0];
  assertEquals(rival.opponent_key, "orphan:orphans:2");
  assertEquals(rival.opponent_user_id, null);
  assertEquals(rival.name, "Orphaned Team");
  assertEquals([rival.wins, rival.losses], [3, 1]);
});

Deno.test("a bye week is not a game against anybody", () => {
  const stats = computeCareerStats({
    sleeper_user_id: ME,
    leagues: [bundle({
      teams: [team(1, ME), team(2, DANA), team(3, OMAR)],
      games: [game(1, 1, 120.0, 2, 90.0)],
      byes: [{ week: 2, roster: 1, points: 115.0 }],
    })],
  });

  assertEquals([stats.wins, stats.losses, stats.ties], [1, 0, 0]);
  // The points were still scored, and could still be someone's best week.
  assertAlmostEquals(stats.points_for, 235.0, 0.001);
  assertEquals(stats.details.seasons[0].weeks_played, 2);
});

// ---------------------------------------------------------------------------
// Draft picks
// ---------------------------------------------------------------------------

Deno.test("a late-round steal outranks the rest of its round", () => {
  const stats = computeCareerStats({ sleeper_user_id: ME, leagues: [draftSeason()] });

  const steal = stats.details.draft.best_picks[0];
  assertEquals(steal.player_name, "Puka Nacua");
  assertEquals(steal.position, "WR");
  assertEquals(steal.round, 9);
  assertEquals(steal.pick, 81);
  assertEquals(steal.season, 2023);
  assertEquals(steal.points, 240);
  // The other nine ninth-rounders in this draft returned 20 points each.
  assertEquals(steal.expected_points, 20);
  assertEquals(steal.surplus, 220);
});

Deno.test("a first-round bust is the worst pick, ahead of cheaper mistakes", () => {
  const stats = computeCareerStats({ sleeper_user_id: ME, leagues: [draftSeason()] });
  const worst = stats.details.draft.worst_picks;

  assertEquals(worst.map((pick) => pick.player_name), [
    "Jonathan Taylor", // 1.01, returned 30 against a round that returned 260
    "Gus Edwards", // a fifth-rounder who never started
    "Tony Pollard", // a sixth-rounder traded away in week 3
  ]);
  assertEquals(worst[0].round, 1);
  assertEquals(worst[0].pick, 1);
  assertEquals(worst[0].points, 30);
  assertEquals(worst[0].expected_points, 260);
  assertEquals(worst[0].surplus, -230);
  assertEquals(worst.length, 3);
  assertEquals(stats.details.draft.leagues_missing_draft_data, 0);
});

Deno.test("a pick is worth only what it scored in this user's starting lineup", () => {
  const stats = computeCareerStats({ sleeper_user_id: ME, leagues: [draftSeason()] });
  const byName = new Map(
    [...stats.details.draft.best_picks, ...stats.details.draft.worst_picks]
      .map((pick) => [pick.player_name, pick]),
  );

  // Benched all season: on the roster, never started, so worth nothing.
  assertEquals(byName.get("Gus Edwards")?.points, 0);
  // Started weeks 1–2 at 11 points a week, then traded away.
  assertEquals(byName.get("Tony Pollard")?.points, 22);
});

Deno.test("keepers are not draft-day decisions and are left out", () => {
  const stats = computeCareerStats({ sleeper_user_id: ME, leagues: [draftSeason()] });
  const ranked = [...stats.details.draft.best_picks, ...stats.details.draft.worst_picks];

  // The keeper is the highest-scoring player on the team by a distance — if it
  // were ranked it would be the best pick of every season it was kept.
  assert(
    !ranked.some((pick) => pick.player_name === "Ja'Marr Chase"),
    "a keeper should never be ranked as a draft pick",
  );
  // Ten picks, one of them a keeper.
  assertEquals(stats.details.draft.scored_picks, 9);
});

Deno.test("an auction has no draft position to be a steal relative to", () => {
  const season = draftSeason();
  const stats = computeCareerStats({
    sleeper_user_id: ME,
    leagues: [{ ...season, drafts: [{ ...season.drafts![0], type: "auction" }] }],
  });

  assertEquals(stats.details.draft.scored_picks, 0);
  assertEquals(stats.details.draft.best_picks, []);
  // The draft is stored and complete — it is simply not rankable by position.
  assertEquals(stats.details.draft.leagues_missing_draft_data, 0);
});

Deno.test("a season with no stored draft is reported, not guessed at", () => {
  const stats = computeCareerStats({
    sleeper_user_id: ME,
    leagues: [bundle({
      teams: [team(1, ME), team(2, DANA)],
      games: [game(1, 1, 120.0, 2, 90.0)],
    })],
  });

  assertEquals(stats.details.draft.best_picks, []);
  assertEquals(stats.details.draft.scored_picks, 0);
  assertEquals(stats.details.draft.leagues_missing_draft_data, 1);
});

Deno.test("picks with no player attached are skipped", () => {
  const season = draftSeason();
  const stats = computeCareerStats({
    sleeper_user_id: ME,
    leagues: [{
      ...season,
      picks: season.picks!.map((pick) =>
        pick.roster_id === 1 ? { ...pick, player_id: null } : pick
      ),
    }],
  });

  assertEquals(stats.details.draft.scored_picks, 0);
});

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------

Deno.test("ownership beats co-ownership when both are present", () => {
  const members: MemberRow[] = [
    { league_id: "l", roster_id: 1, sleeper_user_id: ME },
    { league_id: "l", roster_id: 2, sleeper_user_id: DANA, co_owner_ids: [ME] },
  ];

  // A team someone helps run is not a second career.
  assertEquals([...userRosterIds(members, ME)], [1]);
});

Deno.test("a co-owned roster counts when the user owns nothing else", () => {
  const members: MemberRow[] = [
    { league_id: "l", roster_id: 1, sleeper_user_id: DANA, co_owner_ids: [ME, SAM] },
    { league_id: "l", roster_id: 2, sleeper_user_id: OMAR },
  ];

  assertEquals([...userRosterIds(members, ME)], [1]);
  assertEquals([...userRosterIds(members, LEE)], []);
});

Deno.test("playoffWeekStart falls back to the season's NFL calendar", () => {
  const at = (season: number, settings?: Record<string, unknown>) =>
    playoffWeekStart({ league_id: "l", season, settings });

  assertEquals(at(2024, { playoff_week_start: 15 }), 15);
  assertEquals(at(2024, { playoff_week_start: 14 }), 14);
  // 0 is Sleeper's "unset", not week zero.
  assertEquals(at(2023, { playoff_week_start: 0 }), 15);
  assertEquals(at(2019), 14); // 16-game NFL season
  assertEquals(at(2022), 15); // 17-game NFL season
});

Deno.test("lastCountedWeek stops before the week in progress", () => {
  const at = (status: string, settings?: Record<string, unknown>) =>
    lastCountedWeek({ league_id: "l", season: 2026, status, settings });

  assertEquals(at("complete", { leg: 4 }), Infinity);
  assertEquals(at("in_season", { leg: 4 }), 3);
  assertEquals(at("in_season"), Infinity);
});

// ---------------------------------------------------------------------------
// Identity facts
// ---------------------------------------------------------------------------

Deno.test("facts carry the headline numbers and where they happened", () => {
  const stats = computeCareerStats(fullCareer());
  const facts = new Map(stats.details.facts.map((fact) => [fact.key, fact]));

  assertEquals(facts.get("seasons_played")?.value, 2);

  const highest = facts.get("highest_week");
  assertEquals(highest?.value, 148.6);
  assertEquals(highest?.season, 2023);
  assertEquals(highest?.week, 15);
  assertEquals(highest?.league_name, "Dynasty Dads");
  assertEquals(highest?.opponent, "Omar United");

  // The final, won 131.20–118.90. A playoff nail-biter is exactly the kind of
  // game this fact is for, so playoff weeks are in scope.
  const closest = facts.get("closest_win");
  assertEquals(closest?.value, 12.3);
  assertEquals(closest?.week, 16);
  assertEquals(closest?.opponent, "Priya FC");

  assertEquals(facts.get("biggest_win")?.value, 30);
  assertEquals(facts.get("championships")?.value, 1);
  assertEquals(facts.get("longest_win_streak")?.value, 8);
  assertAlmostEquals(facts.get("points_for")?.value ?? 0, 1974.24, 0.001);
});

Deno.test("facts the data cannot support are left out entirely", () => {
  // Never won a game: no closest win, no blowout, no streak, no title.
  const stats = computeCareerStats({
    sleeper_user_id: ME,
    leagues: [bundle({
      teams: [team(1, ME), team(2, DANA)],
      games: [game(1, 1, 80.0, 2, 120.0)],
    })],
  });

  const keys = stats.details.facts.map((fact) => fact.key);
  assertEquals(keys.includes("closest_win"), false);
  assertEquals(keys.includes("biggest_win"), false);
  assertEquals(keys.includes("championships"), false);
  assertEquals(keys.includes("longest_win_streak"), false);
  assertEquals(keys.includes("highest_week"), true);
});

Deno.test("details carries a version so the app can read it defensively", () => {
  assertEquals(computeCareerStats(fullCareer()).details.version, 1);
});

// ===========================================================================
// Fixtures
// ===========================================================================

interface TeamSpec {
  roster_id: number;
  user: string | null;
  team_name: string;
  finish_rank: number | null;
  co_owners?: string[];
}

function team(
  roster_id: number,
  user: string | null,
  team_name = `Team ${roster_id}`,
  finish_rank: number | null = null,
  co_owners?: string[],
): TeamSpec {
  return { roster_id, user, team_name, finish_rank, co_owners };
}

interface GameSpec {
  week: number;
  a: number;
  aPoints: number;
  b: number;
  bPoints: number;
}

function game(
  week: number,
  a: number,
  aPoints: number,
  b: number,
  bPoints: number,
): GameSpec {
  return { week, a, aPoints, b, bPoints };
}

interface LineupSpec {
  week: number;
  roster: number;
  /** player_id -> points, for the players in the starting lineup. */
  started: Record<string, number>;
  /** On the roster, on the bench: scores points that count for nobody. */
  benched?: Record<string, number>;
}

function bundle(options: {
  id?: string;
  name?: string;
  season?: number;
  status?: string;
  settings?: Record<string, unknown>;
  teams: TeamSpec[];
  games: GameSpec[];
  byes?: { week: number; roster: number; points: number }[];
  custom?: { week: number; roster: number; points: number }[];
  lineups?: LineupSpec[];
  bracket?: BracketEntry[] | null;
  drafts?: DraftRow[];
  picks?: PickRow[];
}): LeagueBundle {
  const leagueId = options.id ?? "league_1";

  const members: MemberRow[] = options.teams.map((spec) => ({
    league_id: leagueId,
    roster_id: spec.roster_id,
    sleeper_user_id: spec.user,
    team_name: spec.team_name,
    co_owner_ids: spec.co_owners ?? null,
    finish_rank: spec.finish_rank,
  }));

  // Sleeper numbers the matchups within a week, from 1.
  const perWeek = new Map<number, number>();
  const nextMatchupId = (week: number) => {
    const next = (perWeek.get(week) ?? 0) + 1;
    perWeek.set(week, next);
    return next;
  };

  const matchups: MatchupRow[] = [];
  for (const spec of options.games) {
    const matchupId = nextMatchupId(spec.week);
    matchups.push(matchupRow(leagueId, spec.week, spec.a, spec.aPoints, matchupId));
    matchups.push(matchupRow(leagueId, spec.week, spec.b, spec.bPoints, matchupId));
  }
  // A bye: Sleeper returns the row with no matchup_id to pair it with.
  for (const spec of options.byes ?? []) {
    matchups.push(matchupRow(leagueId, spec.week, spec.roster, spec.points, null));
  }

  const find = (week: number, roster: number) => {
    const row = matchups.find((m) => m.week === week && m.roster_id === roster);
    if (!row) throw new Error(`fixture has no week ${week} row for roster ${roster}`);
    return row;
  };

  for (const override of options.custom ?? []) {
    find(override.week, override.roster).custom_points = override.points;
  }

  for (const lineup of options.lineups ?? []) {
    const row = find(lineup.week, lineup.roster);
    row.starters = Object.keys(lineup.started);
    row.players_points = { ...lineup.started, ...(lineup.benched ?? {}) };
  }

  return {
    league: {
      league_id: leagueId,
      name: options.name ?? "Dynasty Dads",
      season: options.season ?? 2023,
      status: options.status ?? "complete",
      total_rosters: options.teams.length,
      settings: options.settings ?? { playoff_week_start: 15 },
      winners_bracket: options.bracket === undefined ? null : options.bracket,
    },
    members,
    matchups,
    drafts: options.drafts,
    picks: options.picks,
  };
}

function matchupRow(
  leagueId: string,
  week: number,
  rosterId: number,
  points: number,
  matchupId: number | null,
): MatchupRow {
  return {
    league_id: leagueId,
    week,
    roster_id: rosterId,
    matchup_id: matchupId,
    points,
    custom_points: null,
    starters: [],
    // A week that was played has scoring in it. An unplayed week comes back from
    // Sleeper with zeroes and nothing else, which is what a 0 here stands for.
    players_points: points === 0 ? {} : { "4046": points },
  };
}

/**
 * A real schedule, by the circle method: every roster plays once a week and the
 * opponents rotate, so nobody faces the same team every week.
 */
function rotation(rosters: number[], week: number): [number, number][] {
  const fixed = rosters[0];
  const rest = rosters.slice(1);
  const shift = (week - 1) % rest.length;
  const rotated = [...rest.slice(shift), ...rest.slice(0, shift)];

  const pairs: [number, number][] = [[fixed, rotated[rotated.length - 1]]];
  for (let i = 0; i < (rosters.length - 2) / 2; i++) {
    pairs.push([rotated[i], rotated[rotated.length - 2 - i]]);
  }
  return pairs;
}

/**
 * The career the cross-cutting tests read.
 *
 * 2023 — Dynasty Dads, six teams, finished, won the title: won weeks 1–8, lost
 * 9–14, then a semi-final and a final. 2024 — the same league rolled over to a
 * new league_id and a different roster number, four weeks into the season.
 */
function fullCareer(): CareerInput {
  const rosters = [3, 1, 2, 4, 5, 6];
  const games: GameSpec[] = [];

  for (let week = 1; week <= 14; week++) {
    const mine = week <= 8 ? 120.44 : 90.12;
    for (const [a, b] of rotation(rosters, week)) {
      // Whoever the user faces scores 100.50; the other games are their own.
      const score = (roster: number, opponent: number) =>
        roster === 3 ? mine : opponent === 3 ? 100.5 : 95 + roster;
      games.push(game(week, a, score(a, b), b, score(b, a)));
    }
  }

  // Playoffs. The bracket below is what makes these two the playoff record.
  games.push(game(15, 3, 148.6, 2, 130.4)); // semi-final
  games.push(game(16, 3, 131.2, 4, 118.9)); // final
  // A fifth-place game in a playoff week, between two teams that missed out.
  games.push(game(15, 5, 99.0, 6, 88.0));

  const y2023 = bundle({
    id: "784462448236949504",
    season: 2023,
    teams: [
      team(3, ME, "Bench Mob", 1),
      team(1, DANA, "Dana's Dynasty", 4),
      team(2, OMAR, "Omar United", 3),
      team(4, PRIYA, "Priya FC", 2),
      team(5, LEE, "Lee's Legends", 5),
      team(6, SAM, "Sam I Am", 6),
    ],
    games,
    settings: { playoff_week_start: 15, playoff_teams: 4 },
    bracket: [
      { r: 1, m: 1, t1: 3, t2: 2, w: 3, l: 2 },
      { r: 1, m: 2, t1: 1, t2: 4, w: 4, l: 1 },
      { r: 2, m: 3, t1: { w: 1 }, t2: { w: 2 }, w: 3, l: 4, p: 1 },
    ],
  });

  const y2024 = bundle({
    id: "989264262845517824",
    season: 2024,
    status: "in_season",
    settings: { leg: 5, playoff_week_start: 15, playoff_teams: 4 },
    teams: [
      team(5, ME, "Bench Mob"),
      team(1, DANA, "Dana Mode"),
      team(2, OMAR, "Omar United"),
      team(3, PRIYA, "Priya FC"),
    ],
    games: [
      game(1, 5, 130.0, 1, 100.0),
      game(2, 5, 130.0, 2, 100.0),
      game(3, 5, 130.0, 3, 100.0),
      game(4, 5, 80.0, 1, 100.0),
      // Week 5 is in progress. Partial scores, and must not count.
      game(5, 5, 44.2, 2, 61.0),
    ],
  });

  return { sleeper_user_id: ME, leagues: [y2023, y2024] };
}

// --- The draft ------------------------------------------------------------
//
// A 10-team, 10-round snake draft over a 10-week season. Every pick returns the
// same points as the rest of its round, so the baseline each pick is measured
// against is unambiguous, and the user's picks are the only exceptions:
//
//   1.01  Jonathan Taylor  30 of an expected 260 — the bust
//   5.41  Gus Edwards       0 — on the roster, never started
//   6.60  Tony Pollard     22 — started twice, then traded away
//   9.81  Puka Nacua      240 of an expected 20 — the steal
//   10.100 Ja'Marr Chase  250 — a keeper, and therefore not a draft pick

const DRAFT_TEAMS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
const DRAFT_WEEKS = 10;
/** Season points a round returns, from the first round down to the tenth. */
const ROUND_POINTS = [260, 230, 200, 170, 140, 110, 80, 50, 20, 10];

/** The user's picks, by round: their Sleeper id and who they are. */
const MY_PICKS: Record<number, [string, Record<string, string>]> = {
  1: ["4035", { first_name: "Jonathan", last_name: "Taylor", position: "RB" }],
  2: ["6794", { first_name: "Justin", last_name: "Jefferson", position: "WR" }],
  3: ["4034", { first_name: "Christian", last_name: "McCaffrey", position: "RB" }],
  4: ["5849", { first_name: "Josh", last_name: "Allen", position: "QB" }],
  5: ["5967", { first_name: "Gus", last_name: "Edwards", position: "RB" }],
  6: ["6813", { first_name: "Tony", last_name: "Pollard", position: "RB" }],
  7: ["4199", { first_name: "Dalton", last_name: "Schultz", position: "TE" }],
  8: ["7600", { first_name: "Rachaad", last_name: "White", position: "RB" }],
  9: ["9493", { first_name: "Puka", last_name: "Nacua", position: "WR" }],
  10: ["6803", { first_name: "Ja'Marr", last_name: "Chase", position: "WR" }],
};

function draftSeason(): LeagueBundle {
  const draftId = "1017365293058678784";
  const picks: PickRow[] = [];
  let pickNo = 0;

  for (let round = 1; round <= 10; round++) {
    // A snake draft reverses every second round.
    const order = round % 2 === 1 ? DRAFT_TEAMS : [...DRAFT_TEAMS].reverse();
    for (const roster of order) {
      pickNo++;
      const [playerId, metadata] = roster === 1
        ? MY_PICKS[round]
        : [`${roster}${String(round).padStart(2, "0")}`, {
          first_name: "Roster",
          last_name: `${roster} round ${round}`,
        }];

      picks.push({
        draft_id: draftId,
        pick_no: pickNo,
        round,
        draft_slot: round % 2 === 1
          ? DRAFT_TEAMS.indexOf(roster) + 1
          : 11 - (DRAFT_TEAMS.indexOf(roster) + 1),
        player_id: playerId,
        roster_id: roster,
        picked_by: null,
        // Round 10 was kept, not drafted.
        is_keeper: round === 10 && roster === 1,
        metadata,
      });
    }
  }

  const playerId = (roster: number, round: number) =>
    roster === 1 ? MY_PICKS[round][0] : `${roster}${String(round).padStart(2, "0")}`;
  const weekly = (round: number) => ROUND_POINTS[round - 1] / DRAFT_WEEKS;

  const lineups: LineupSpec[] = [];
  const games: GameSpec[] = [];

  for (let week = 1; week <= DRAFT_WEEKS; week++) {
    for (const roster of DRAFT_TEAMS) {
      const started: Record<string, number> = {};
      const benched: Record<string, number> = {};

      if (roster === 1) {
        // The bust starts anyway (he was a first-rounder), the fifth-rounder
        // never does, the sixth-rounder is gone after week 2, and the keeper
        // carries the team.
        started[playerId(1, 1)] = 3;
        for (const round of [2, 3, 4, 7, 8, 10]) {
          started[playerId(1, round)] = weekly(round);
        }
        started[playerId(1, 9)] = 24;
        benched[playerId(1, 5)] = weekly(5);
        if (week <= 2) started[playerId(1, 6)] = weekly(6);
        else started["9999"] = 9; // the waiver add who replaced him
      } else {
        for (let round = 1; round <= 9; round++) {
          started[playerId(roster, round)] = weekly(round);
        }
        benched[playerId(roster, 10)] = weekly(10);
      }

      lineups.push({ week, roster, started, benched });
    }

    for (const [a, b] of rotation(DRAFT_TEAMS, week)) {
      games.push(
        game(week, a, lineupTotal(lineups, week, a), b, lineupTotal(lineups, week, b)),
      );
    }
  }

  return bundle({
    id: "draft_league",
    season: 2023,
    teams: [
      team(1, ME, "Bench Mob"),
      team(2, DANA),
      team(3, OMAR),
      team(4, PRIYA),
      team(5, LEE),
      team(6, SAM),
      ...[7, 8, 9, 10].map((roster) => team(roster, `9${roster}9999999999999999`)),
    ],
    games,
    lineups,
    drafts: [{
      draft_id: draftId,
      league_id: "draft_league",
      season: 2023,
      type: "snake",
      rounds: 10,
    }],
    picks,
  });
}

/** A week's score is the sum of the starting lineup, as it is in a real league. */
function lineupTotal(lineups: LineupSpec[], week: number, roster: number): number {
  const lineup = lineups.find((l) => l.week === week && l.roster === roster);
  if (!lineup) throw new Error(`no lineup for roster ${roster} in week ${week}`);
  return Math.round(Object.values(lineup.started).reduce((a, b) => a + b, 0) * 100) / 100;
}
