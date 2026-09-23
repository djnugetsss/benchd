/**
 * career.ts — the career stats computation.
 *
 * Pure functions over rows already read out of Postgres: no network, no
 * Supabase client, no clock. `sync-sleeper` fetches the rows and calls
 * `computeCareerStats` at the end of a run; everything here can be unit tested
 * with fixtures (see `career.test.ts`).
 *
 * The shape of the answer is deliberate. The promoted columns on `career_stats`
 * (wins/losses/ties/points_for/points_against) carry the **regular season**,
 * which is what Sleeper's own roster record means and therefore what a user
 * recognises as "my record". Playoffs, streaks, drafts, rivalries and the
 * per-season timeline live in `details`.
 *
 * Four things make this harder than summing columns, and each is handled
 * explicitly below:
 *
 *   1. Sleeper returns matchup rows for weeks that have not been played yet,
 *      with points of 0. Counted naively they become losses, or 0–0 ties.
 *   2. Median-scoring leagues (`league_average_match`) settle two results a
 *      week: one against an opponent, one against the league median.
 *   3. Playoff weeks in `matchups` mix the championship bracket with the
 *      consolation bracket. Only the winners bracket is a playoff record.
 *   4. A roster is not a person. Rosters change hands, a user's roster_id
 *      changes between seasons of the same league, and co-owned rosters exist.
 */

import { round2 } from "./season.ts";

// ---------------------------------------------------------------------------
// Input — Postgres rows, passed through unchanged
// ---------------------------------------------------------------------------

/** One entry of Sleeper's winners_bracket, as stored on `leagues`. */
export interface BracketEntry {
  r?: number | null;
  m?: number | null;
  /** A roster id, or `{ w: 3 }` / `{ l: 3 }` meaning "whoever wins/loses m=3". */
  t1?: number | { w?: number; l?: number } | null;
  t2?: number | { w?: number; l?: number } | null;
  w?: number | null;
  l?: number | null;
  /** Placement this game decides: 1 = championship, 3 = third place. */
  p?: number | null;
}

export interface LeagueRow {
  league_id: string;
  name?: string | null;
  season: number;
  status?: string | null;
  total_rosters?: number | null;
  settings?: Record<string, unknown> | null;
  winners_bracket?: BracketEntry[] | null;
}

export interface MemberRow {
  league_id: string;
  roster_id: number;
  sleeper_user_id?: string | null;
  team_name?: string | null;
  co_owner_ids?: string[] | null;
  wins?: number | null;
  losses?: number | null;
  ties?: number | null;
  fpts?: number | string | null;
  fpts_against?: number | string | null;
  finish_rank?: number | null;
}

export interface MatchupRow {
  league_id: string;
  week: number;
  roster_id: number;
  matchup_id?: number | null;
  points?: number | string | null;
  custom_points?: number | string | null;
  starters?: string[] | null;
  players_points?: Record<string, number> | null;
}

export interface DraftRow {
  draft_id: string;
  league_id: string;
  season?: number | null;
  type?: string | null;
  rounds?: number | null;
}

export interface PickRow {
  draft_id: string;
  pick_no: number;
  round: number;
  draft_slot?: number | null;
  player_id?: string | null;
  roster_id?: number | null;
  picked_by?: string | null;
  is_keeper?: boolean | null;
  metadata?: Record<string, string> | null;
}

/** Everything stored for one league-season. */
export interface LeagueBundle {
  league: LeagueRow;
  /** Every roster in the league, not just the user's — opponents are needed. */
  members: MemberRow[];
  /** Every roster's weeks. Needed for opponent points and league medians. */
  matchups: MatchupRow[];
  drafts?: DraftRow[];
  picks?: PickRow[];
}

export interface CareerInput {
  sleeper_user_id: string;
  leagues: LeagueBundle[];
}

// ---------------------------------------------------------------------------
// Output
// ---------------------------------------------------------------------------

export interface RecordSummary {
  wins: number;
  losses: number;
  ties: number;
  games: number;
  /** A tie is half a win. `null` when nothing has been played. */
  win_pct: number | null;
  points_for: number;
  points_against: number;
  points_per_game: number | null;
}

export interface PlayoffSummary {
  wins: number;
  losses: number;
  games: number;
  win_pct: number | null;
  /** Seasons in which the user reached the winners bracket. */
  appearances: number;
  championships: number;
  runner_ups: number;
  finals: number;
}

export interface StreakSummary {
  length: number;
  league_id: string;
  league_name: string;
  season: number;
  start_week: number;
  end_week: number;
}

export interface SeasonSummary {
  season: number;
  league_id: string;
  league_name: string;
  roster_id: number;
  team_name: string | null;
  wins: number;
  losses: number;
  ties: number;
  games: number;
  win_pct: number | null;
  points_for: number;
  points_against: number;
  points_per_game: number | null;
  playoff_points_for: number;
  high_week: number | null;
  low_week: number | null;
  /** Regular season weeks with a score, byes included. What points_for covers. */
  regular_weeks: number;
  /** Every week with a score, playoffs and consolation games included. */
  weeks_played: number;
  finish_rank: number | null;
  playoff_wins: number;
  playoff_losses: number;
  made_playoffs: boolean;
  champion: boolean;
  runner_up: boolean;
  /** The season is still being played, so its record is not final. */
  in_progress: boolean;
  /** Results include a weekly match against the league median. */
  median_scoring: boolean;
  /**
   * Where the record came from. `roster_totals` means no weeks were stored for
   * this league-season, so Sleeper's season totals were used and the week-level
   * numbers on this row are empty.
   */
  record_source: "matchups" | "roster_totals";
}

export interface PickScore {
  player_id: string;
  player_name: string | null;
  position: string | null;
  season: number;
  league_id: string;
  league_name: string;
  round: number;
  pick: number;
  draft_slot: number | null;
  /** Points the player scored while in this user's starting lineup that season. */
  points: number;
  /** What the average pick in the same round of the same draft returned. */
  expected_points: number;
  /** points − expected_points. The ranking key: a steal is a big surplus. */
  surplus: number;
}

export interface Rivalry {
  /** Stable identity: a Sleeper user id, or `orphan:<league>:<roster>`. */
  opponent_key: string;
  opponent_user_id: string | null;
  name: string;
  games: number;
  wins: number;
  losses: number;
  ties: number;
  win_pct: number | null;
  points_for: number;
  points_against: number;
  seasons: number[];
}

export interface Fact {
  key: string;
  label: string;
  value: number;
  unit: "points" | "count" | "seasons" | "games";
  season?: number;
  week?: number;
  league_name?: string;
  opponent?: string;
  margin?: number;
}

export interface CareerDetails {
  version: number;
  regular_season: RecordSummary;
  playoffs: PlayoffSummary;
  streaks: {
    longest_win: StreakSummary | null;
    longest_loss: StreakSummary | null;
  };
  seasons: SeasonSummary[];
  best_season: SeasonSummary | null;
  worst_season: SeasonSummary | null;
  draft: {
    best_picks: PickScore[];
    worst_picks: PickScore[];
    scored_picks: number;
    /** League-seasons where the user played but no usable draft was stored. */
    leagues_missing_draft_data: number;
  };
  rivalries: {
    /** Games needed before a head-to-head counts as a rivalry. */
    threshold: number;
    all: Rivalry[];
    most_played: Rivalry | null;
    /** The opponent this user has beaten most often. */
    best: Rivalry | null;
    /** The opponent who has beaten this user most often. */
    worst: Rivalry | null;
  };
  facts: Fact[];
}

/** Exactly the columns `career_stats` takes, plus the jsonb payload. */
export interface CareerStatsResult {
  wins: number;
  losses: number;
  ties: number;
  championships: number;
  seasons: number;
  leagues_count: number;
  points_for: number;
  points_against: number;
  details: CareerDetails;
}

export const DETAILS_VERSION = 1;

/** Below this, a head-to-head is a coincidence rather than a rivalry. */
export const RIVALRY_MIN_GAMES = 4;

/** How many picks and rivals the profile features. */
const TOP_N = 3;

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

export function computeCareerStats(input: CareerInput): CareerStatsResult {
  const leagueResults = input.leagues
    .map((bundle) => summarizeLeague(bundle, input.sleeper_user_id))
    .filter((result): result is LeagueResult => result !== null);

  const seasons = leagueResults.flatMap((r) => r.seasons)
    .sort((a, b) => a.season - b.season || a.league_name.localeCompare(b.league_name));

  const weeks = leagueResults.flatMap((r) => r.weeks);
  const regularSeason = totalRegularSeason(seasons);
  const playoffs = totalPlayoffs(seasons);
  const streaks = bestStreaks(leagueResults);
  const { best, worst } = bestAndWorstSeason(seasons);
  const rivalries = mergeRivalries(leagueResults);
  const draft = rankPicks(leagueResults);

  return {
    wins: regularSeason.wins,
    losses: regularSeason.losses,
    ties: regularSeason.ties,
    championships: playoffs.championships,
    seasons: new Set(seasons.map((s) => s.season)).size,
    leagues_count: new Set(seasons.map((s) => s.league_id)).size,
    points_for: regularSeason.points_for,
    points_against: regularSeason.points_against,
    details: {
      version: DETAILS_VERSION,
      regular_season: regularSeason,
      playoffs,
      streaks,
      seasons,
      best_season: best,
      worst_season: worst,
      draft,
      rivalries,
      facts: buildFacts(seasons, weeks, regularSeason, playoffs, streaks),
    },
  };
}

// ---------------------------------------------------------------------------
// One league-season
// ---------------------------------------------------------------------------

/** One week the user actually played. The basis for everything week-shaped. */
interface WeekResult {
  league_id: string;
  league_name: string;
  season: number;
  week: number;
  points: number;
  playoff: boolean;
  opponent_key: string | null;
  opponent_user_id: string | null;
  opponent_name: string | null;
  opponent_points: number | null;
  /** Positive when the user won. `null` when there was no opponent. */
  margin: number | null;
  result: "W" | "L" | "T" | null;
}

interface LeagueResult {
  seasons: SeasonSummary[];
  weeks: WeekResult[];
  /** Candidate runs, already scoped to one league-season so nothing interleaves. */
  winStreaks: StreakSummary[];
  lossStreaks: StreakSummary[];
  rivalries: Map<string, Rivalry>;
  picks: PickScore[];
  missingDraftData: boolean;
}

/**
 * Reduces one stored league-season to the user's slice of it.
 *
 * Returns `null` when the user owns no roster in the league. That is a normal
 * case, not an error: the sync follows `previous_league_id` chains into seasons
 * the account was never a member of, and those must not count toward anything.
 */
function summarizeLeague(bundle: LeagueBundle, userId: string): LeagueResult | null {
  const { league, members } = bundle;
  const rosterIds = userRosterIds(members, userId);
  if (rosterIds.size === 0) return null;

  const leagueName = league.name ?? "Untitled league";
  const memberByRoster = new Map(members.map((m) => [m.roster_id, m]));
  const firstPlayoffWeek = playoffWeekStart(league);
  const lastWeek = lastCountedWeek(league);
  const medianScoring = isMedianLeague(league);
  const inProgress = league.status !== "complete";

  const byWeek = new Map<number, MatchupRow[]>();
  for (const row of bundle.matchups) {
    const rows = byWeek.get(row.week);
    if (rows) rows.push(row);
    else byWeek.set(row.week, [row]);
  }
  const orderedWeeks = [...byWeek.keys()].sort((a, b) => a - b);

  const result: LeagueResult = {
    seasons: [],
    weeks: [],
    winStreaks: [],
    lossStreaks: [],
    rivalries: new Map(),
    picks: [],
    missingDraftData: false,
  };

  for (const rosterId of rosterIds) {
    const member = memberByRoster.get(rosterId);
    const weeks: WeekResult[] = [];
    let medianWins = 0;
    let medianLosses = 0;
    let medianTies = 0;

    for (const week of orderedWeeks) {
      if (week > lastWeek) continue;

      const rows = byWeek.get(week)!;
      const own = rows.find((row) => row.roster_id === rosterId);
      if (!own) continue;

      // Sleeper hands back every future week of an in-season league with zeroes
      // in it. Without this the rest of the season becomes a losing streak.
      if (!weekWasPlayed(rows)) continue;

      const points = pointsOf(own) ?? 0;
      const playoff = week >= firstPlayoffWeek;
      const opponent = opponentRow(rows, own, rosterIds);
      const opponentMember = opponent
        ? memberByRoster.get(opponent.roster_id)
        : undefined;
      const opponentPoints = opponent ? pointsOf(opponent) ?? 0 : null;

      weeks.push({
        league_id: league.league_id,
        league_name: leagueName,
        season: league.season,
        week,
        points: round2(points),
        playoff,
        opponent_key: opponent
          ? opponentKey(league.league_id, opponent.roster_id, opponentMember)
          : null,
        opponent_user_id: opponentMember?.sleeper_user_id ?? null,
        opponent_name: opponent ? teamName(opponent.roster_id, opponentMember) : null,
        opponent_points: opponentPoints === null ? null : round2(opponentPoints),
        margin: opponentPoints === null ? null : round2(points - opponentPoints),
        result: opponentPoints === null ? null : outcome(points, opponentPoints),
      });

      // The league median is a second, separate result for the same week. It is
      // why a 14-week median league can produce a 20-8 record.
      if (medianScoring && !playoff) {
        const median = medianPoints(rows);
        if (median !== null) {
          const versusMedian = outcome(points, median);
          if (versusMedian === "W") medianWins++;
          else if (versusMedian === "L") medianLosses++;
          else medianTies++;
        }
      }
    }

    const regular = weeks.filter((w) => !w.playoff);
    const decided = regular.filter((w) => w.result !== null);
    const bracket = bracketRecord(league, rosterId, member);

    // No weeks stored for a league the user has a roster in: the sync wrote the
    // rosters and then ran out of its time budget before the matchups, or was
    // killed between the two. Sleeper's own season totals are a better answer
    // than a phantom 0–0, and the next hourly run fills in the weeks.
    const fromRoster = weeks.length === 0 && member !== undefined;

    const wins = fromRoster
      ? whole(member!.wins)
      : decided.filter((w) => w.result === "W").length + medianWins;
    const losses = fromRoster
      ? whole(member!.losses)
      : decided.filter((w) => w.result === "L").length + medianLosses;
    const ties = fromRoster
      ? whole(member!.ties)
      : decided.filter((w) => w.result === "T").length + medianTies;
    const pointsFor = fromRoster
      ? numberOrNull(member!.fpts) ?? 0
      : sum(regular.map((w) => w.points));
    // Deliberately head-to-head only: the median match has no opponent, so
    // adding the median to points_against would invent points nobody scored.
    const pointsAgainst = fromRoster
      ? numberOrNull(member!.fpts_against) ?? 0
      : sum(decided.map((w) => w.opponent_points ?? 0));

    result.seasons.push({
      season: league.season,
      league_id: league.league_id,
      league_name: leagueName,
      roster_id: rosterId,
      team_name: member?.team_name ?? null,
      wins,
      losses,
      ties,
      games: wins + losses + ties,
      win_pct: winPct(wins, losses, ties),
      points_for: round2(pointsFor),
      points_against: round2(pointsAgainst),
      points_per_game: regular.length > 0 ? round2(pointsFor / regular.length) : null,
      playoff_points_for: round2(
        sum(weeks.filter((w) => w.playoff).map((w) => w.points)),
      ),
      high_week: weeks.length > 0
        ? round2(Math.max(...weeks.map((w) => w.points)))
        : null,
      low_week: weeks.length > 0 ? round2(Math.min(...weeks.map((w) => w.points))) : null,
      regular_weeks: regular.length,
      weeks_played: weeks.length,
      finish_rank: member?.finish_rank ?? null,
      playoff_wins: bracket.wins,
      playoff_losses: bracket.losses,
      made_playoffs: bracket.appeared,
      champion: bracket.champion,
      runner_up: bracket.runnerUp,
      in_progress: inProgress,
      median_scoring: medianScoring,
      record_source: fromRoster ? "roster_totals" : "matchups",
    });

    result.weeks.push(...weeks);

    const run = longestRuns(regular, {
      league_id: league.league_id,
      league_name: leagueName,
      season: league.season,
    });
    if (run.win) result.winStreaks.push(run.win);
    if (run.loss) result.lossStreaks.push(run.loss);

    for (const week of weeks) {
      if (!week.opponent_key) continue;
      tallyRivalry(result.rivalries, week);
    }

    const scored = scoreDraftPicks(bundle, rosterId, leagueName);
    result.picks.push(...scored.picks);
    if (scored.missing && weeks.length > 0) result.missingDraftData = true;
  }

  return result;
}

// ---------------------------------------------------------------------------
// Identity: which rosters are this user's
// ---------------------------------------------------------------------------

/**
 * The rosters a Sleeper user controls in one league.
 *
 * Ownership wins over co-ownership: in a league where someone owns one team and
 * helps run another, only the team they own is theirs. Co-owned rosters count
 * only when they own nothing — otherwise a co-manager would inherit a second
 * career's worth of wins.
 *
 * What cannot be recovered here: a roster that changed hands mid-season. Sleeper
 * reports only the current owner, so the whole season is attributed to them.
 */
export function userRosterIds(members: MemberRow[], userId: string): Set<number> {
  const owned = members
    .filter((m) => m.sleeper_user_id === userId)
    .map((m) => m.roster_id);
  if (owned.length > 0) return new Set(owned);

  return new Set(
    members
      .filter((m) => (m.co_owner_ids ?? []).includes(userId))
      .map((m) => m.roster_id),
  );
}

function opponentKey(
  leagueId: string,
  rosterId: number,
  member: MemberRow | undefined,
): string {
  // Sleeper allows a roster with no manager. It still plays games, so it still
  // needs an identity — scoped to the league, since it is not a person.
  return member?.sleeper_user_id ?? `orphan:${leagueId}:${rosterId}`;
}

function teamName(rosterId: number, member: MemberRow | undefined): string {
  return member?.team_name?.trim() || `Team ${rosterId}`;
}

// ---------------------------------------------------------------------------
// League settings
// ---------------------------------------------------------------------------

/**
 * The first week of the playoffs.
 *
 * Sleeper stores this per league, but older leagues and a few hand-made ones
 * omit it. The fallback is the NFL's own history: the regular season grew from
 * 16 to 17 games in 2021, which moved the default fantasy playoff start from
 * week 14 to week 15.
 */
export function playoffWeekStart(league: LeagueRow): number {
  const configured = Number(league.settings?.playoff_week_start);
  if (Number.isFinite(configured) && configured >= 2) return configured;
  return league.season >= 2021 ? 15 : 14;
}

/** Whether every week also settles a result against the league median. */
export function isMedianLeague(league: LeagueRow): boolean {
  return Number(league.settings?.league_average_match) === 1;
}

/**
 * The last week whose result can be trusted.
 *
 * A finished league has no such limit. A live one does: Sleeper's `leg` is the
 * week in progress, and a week in progress has partial scores — counting it
 * would put a phantom loss on the profile every Thursday night. Excluding it
 * means a completed week lands a day late, which is the better failure.
 */
export function lastCountedWeek(league: LeagueRow): number {
  if (league.status === "complete") return Number.POSITIVE_INFINITY;
  const leg = Number(league.settings?.leg);
  if (Number.isFinite(leg) && leg >= 1) return leg - 1;
  return Number.POSITIVE_INFINITY;
}

// ---------------------------------------------------------------------------
// Weeks
// ---------------------------------------------------------------------------

/** A commissioner's manual override replaces the computed score. */
function pointsOf(row: MatchupRow): number | null {
  const custom = numberOrNull(row.custom_points);
  if (custom !== null) return custom;
  return numberOrNull(row.points);
}

/**
 * Whether a week happened at all.
 *
 * Judged across the whole week rather than one roster, so a real 0-point week —
 * an abandoned lineup, every starter on bye — still counts as the loss it was.
 */
function weekWasPlayed(rows: MatchupRow[]): boolean {
  return rows.some((row) => {
    const points = pointsOf(row);
    if (points !== null && points !== 0) return true;
    return Object.values(row.players_points ?? {}).some((value) => Number(value) !== 0);
  });
}

function opponentRow(
  rows: MatchupRow[],
  own: MatchupRow,
  ownRosters: Set<number>,
): MatchupRow | null {
  // No matchup_id means a bye, or an offseason week Sleeper still answers for.
  if (own.matchup_id === null || own.matchup_id === undefined) return null;

  return rows.find((row) =>
    row.matchup_id === own.matchup_id &&
    row.roster_id !== own.roster_id &&
    // Guard against a user who somehow owns both sides: that is not a game.
    !ownRosters.has(row.roster_id)
  ) ?? null;
}

function outcome(points: number, against: number): "W" | "L" | "T" {
  if (points > against) return "W";
  if (points < against) return "L";
  return "T";
}

/** The league median for a week, over the rosters that actually played. */
function medianPoints(rows: MatchupRow[]): number | null {
  const values = rows
    .map(pointsOf)
    .filter((value): value is number => value !== null)
    .sort((a, b) => a - b);
  if (values.length === 0) return null;

  const middle = Math.floor(values.length / 2);
  return values.length % 2 === 1
    ? values[middle]
    : (values[middle - 1] + values[middle]) / 2;
}

// ---------------------------------------------------------------------------
// Playoffs
// ---------------------------------------------------------------------------

interface BracketRecord {
  wins: number;
  losses: number;
  appeared: boolean;
  champion: boolean;
  runnerUp: boolean;
}

/**
 * A roster's playoff record, read from the winners bracket.
 *
 * The bracket is the only honest source. Playoff-week rows in `matchups` also
 * contain the consolation bracket, so counting weeks would credit a team that
 * missed the playoffs with a playoff run — and charge an eliminated team with
 * losses in games that decided nothing.
 *
 * Falls back to `finish_rank` when no bracket is stored, which happens between
 * a league being synced and its next sync. `finish_rank` is itself derived from
 * the bracket, so a title is never lost; only the round-by-round record is.
 */
export function bracketRecord(
  league: LeagueRow,
  rosterId: number,
  member: MemberRow | undefined,
): BracketRecord {
  const bracket = league.winners_bracket;
  const finishRank = member?.finish_rank ?? null;

  if (!bracket || bracket.length === 0) {
    return {
      wins: 0,
      losses: 0,
      appeared: finishRank !== null && finishRank <= playoffTeams(league),
      champion: finishRank === 1,
      runnerUp: finishRank === 2,
    };
  }

  let wins = 0;
  let losses = 0;
  let appeared = false;
  let champion = false;
  let runnerUp = false;

  for (const entry of bracket) {
    // t1/t2 are roster ids once known and `{ w: 3 }` placeholders before that.
    for (const slot of [entry.t1, entry.t2]) {
      if (typeof slot === "number" && slot === rosterId) appeared = true;
    }
    if (entry.w === rosterId || entry.l === rosterId) appeared = true;

    if (entry.w === rosterId) wins++;
    if (entry.l === rosterId) losses++;

    if (entry.p === 1) {
      if (entry.w === rosterId) champion = true;
      if (entry.l === rosterId) runnerUp = true;
    }
  }

  return { wins, losses, appeared, champion, runnerUp };
}

function playoffTeams(league: LeagueRow): number {
  const configured = Number(league.settings?.playoff_teams);
  return Number.isFinite(configured) && configured > 0 ? configured : 6;
}

// ---------------------------------------------------------------------------
// Streaks
// ---------------------------------------------------------------------------

/**
 * The longest winning and losing runs inside one league-season.
 *
 * Scoped that way on purpose. Someone in three leagues at once plays three
 * parallel schedules, and interleaving them by week would manufacture a
 * "9-game win streak" out of games from different competitions. Head-to-head
 * regular season games only: a bye, a consolation game, or a result against the
 * league median has no place in the week-by-week order of a season.
 */
function longestRuns(
  weeks: WeekResult[],
  context: { league_id: string; league_name: string; season: number },
): { win: StreakSummary | null; loss: StreakSummary | null } {
  let win: StreakSummary | null = null;
  let loss: StreakSummary | null = null;

  let kind: "W" | "L" | null = null;
  let length = 0;
  let startWeek = 0;
  let endWeek = 0;

  const flush = () => {
    if (kind === null || length === 0) return;
    const run: StreakSummary = {
      ...context,
      length,
      start_week: startWeek,
      end_week: endWeek,
    };
    if (kind === "W" && (!win || length > win.length)) win = run;
    if (kind === "L" && (!loss || length > loss.length)) loss = run;
  };

  for (const week of weeks) {
    if (week.result === null) continue;
    // A tie ends a streak without starting one. It is neither.
    if (week.result === "T") {
      flush();
      kind = null;
      length = 0;
      continue;
    }

    if (week.result === kind) {
      length++;
      endWeek = week.week;
    } else {
      flush();
      kind = week.result;
      length = 1;
      startWeek = week.week;
      endWeek = week.week;
    }
  }
  flush();

  return { win, loss };
}

function bestStreaks(results: LeagueResult[]): CareerDetails["streaks"] {
  return {
    longest_win: longest(results.flatMap((r) => r.winStreaks)),
    longest_loss: longest(results.flatMap((r) => r.lossStreaks)),
  };
}

/** The longest run, breaking a tie toward the most recent season. */
function longest(runs: StreakSummary[]): StreakSummary | null {
  return [...runs].sort((a, b) => b.length - a.length || b.season - a.season)[0] ?? null;
}

// ---------------------------------------------------------------------------
// Totals
// ---------------------------------------------------------------------------

function totalRegularSeason(seasons: SeasonSummary[]): RecordSummary {
  const wins = sum(seasons.map((s) => s.wins));
  const losses = sum(seasons.map((s) => s.losses));
  const ties = sum(seasons.map((s) => s.ties));
  const pointsFor = sum(seasons.map((s) => s.points_for));
  // Regular season weeks only: `weeks_played` counts playoff weeks too, and
  // dividing regular season points by it would understate every average.
  const weeks = sum(seasons.map((s) => s.regular_weeks));

  return {
    wins,
    losses,
    ties,
    games: wins + losses + ties,
    win_pct: winPct(wins, losses, ties),
    points_for: round2(pointsFor),
    points_against: round2(sum(seasons.map((s) => s.points_against))),
    points_per_game: weeks > 0 ? round2(pointsFor / weeks) : null,
  };
}

function totalPlayoffs(seasons: SeasonSummary[]): PlayoffSummary {
  const wins = sum(seasons.map((s) => s.playoff_wins));
  const losses = sum(seasons.map((s) => s.playoff_losses));
  const championships = seasons.filter((s) => s.champion).length;
  const runnerUps = seasons.filter((s) => s.runner_up).length;

  return {
    wins,
    losses,
    games: wins + losses,
    win_pct: winPct(wins, losses, 0),
    appearances: seasons.filter((s) => s.made_playoffs).length,
    championships,
    runner_ups: runnerUps,
    finals: championships + runnerUps,
  };
}

/**
 * Best and worst season, by win percentage and points as the tie-break.
 *
 * Seasons still in progress are excluded whenever a finished one exists: a 3–0
 * start is not someone's best season, and it would knock a real championship
 * year off the profile every September.
 */
function bestAndWorstSeason(
  seasons: SeasonSummary[],
): { best: SeasonSummary | null; worst: SeasonSummary | null } {
  const decided = seasons.filter((s) => s.games > 0);
  if (decided.length === 0) return { best: null, worst: null };

  const finished = decided.filter((s) => !s.in_progress);
  const pool = finished.length > 0 ? finished : decided;

  const ranked = [...pool].sort((a, b) =>
    (b.win_pct ?? 0) - (a.win_pct ?? 0) ||
    b.points_for - a.points_for ||
    b.season - a.season
  );

  return { best: ranked[0], worst: ranked[ranked.length - 1] };
}

// ---------------------------------------------------------------------------
// Rivalries
// ---------------------------------------------------------------------------

function tallyRivalry(into: Map<string, Rivalry>, week: WeekResult) {
  const key = week.opponent_key!;
  let rivalry = into.get(key);
  if (!rivalry) {
    rivalry = {
      opponent_key: key,
      opponent_user_id: week.opponent_user_id,
      name: week.opponent_name ?? "Unknown team",
      games: 0,
      wins: 0,
      losses: 0,
      ties: 0,
      win_pct: null,
      points_for: 0,
      points_against: 0,
      seasons: [],
    };
    into.set(key, rivalry);
  }

  if (week.result === null) return;
  rivalry.games++;
  if (week.result === "W") rivalry.wins++;
  else if (week.result === "L") rivalry.losses++;
  else rivalry.ties++;
  rivalry.points_for = round2(rivalry.points_for + week.points);
  rivalry.points_against = round2(rivalry.points_against + (week.opponent_points ?? 0));
  if (!rivalry.seasons.includes(week.season)) rivalry.seasons.push(week.season);
}

function mergeRivalries(results: LeagueResult[]): CareerDetails["rivalries"] {
  const merged = new Map<string, Rivalry>();

  for (const result of results) {
    for (const [key, incoming] of result.rivalries) {
      const existing = merged.get(key);
      if (!existing) {
        merged.set(key, { ...incoming, seasons: [...incoming.seasons] });
        continue;
      }
      existing.games += incoming.games;
      existing.wins += incoming.wins;
      existing.losses += incoming.losses;
      existing.ties += incoming.ties;
      existing.points_for = round2(existing.points_for + incoming.points_for);
      existing.points_against = round2(existing.points_against + incoming.points_against);
      for (const season of incoming.seasons) {
        if (!existing.seasons.includes(season)) existing.seasons.push(season);
      }
      // Names change between seasons; the most recent one is the one they use.
      if (Math.max(...incoming.seasons) >= Math.max(...existing.seasons)) {
        existing.name = incoming.name;
      }
    }
  }

  const all = [...merged.values()]
    .filter((r) => r.games >= RIVALRY_MIN_GAMES)
    .map((r) => ({
      ...r,
      seasons: [...r.seasons].sort((a, b) => a - b),
      win_pct: winPct(r.wins, r.losses, r.ties),
    }))
    .sort((a, b) => b.games - a.games || b.wins - a.wins || a.name.localeCompare(b.name));

  const mostPlayed = all[0] ?? null;

  const best =
    [...all].sort((a, b) =>
      b.wins - a.wins || (b.win_pct ?? 0) - (a.win_pct ?? 0) || b.games - a.games
    )[0] ?? null;

  const worst =
    [...all].sort((a, b) =>
      b.losses - a.losses || (a.win_pct ?? 1) - (b.win_pct ?? 1) || b.games - a.games
    )[0] ?? null;

  return { threshold: RIVALRY_MIN_GAMES, all, most_played: mostPlayed, best, worst };
}

// ---------------------------------------------------------------------------
// Draft picks
// ---------------------------------------------------------------------------

/**
 * Scores one roster's draft.
 *
 * A pick is worth what it actually did for the team that made it: the points
 * the player scored **while in that roster's starting lineup that season**. A
 * player drafted and then traded away contributes only the weeks he started
 * here; a player who sat on the bench all year contributes nothing, which is
 * exactly the judgment a draft grade should make.
 *
 * Raw points cannot rank picks on their own — a 1.01 outscoring a 14th-rounder
 * is not news. Each pick is measured against what the *same round of the same
 * draft* returned, so the comparison is against the picks made alongside it,
 * under the same scoring settings, in the same season. A late-round steal shows
 * up as a large positive surplus; a first-round bust as a large negative one.
 * The baseline is self-calibrating, so a partially played season simply
 * produces smaller surpluses rather than skewed ones.
 */
function scoreDraftPicks(
  bundle: LeagueBundle,
  rosterId: number,
  leagueName: string,
): { picks: PickScore[]; missing: boolean } {
  const drafts = bundle.drafts ?? [];
  const allPicks = bundle.picks ?? [];
  if (drafts.length === 0 || allPicks.length === 0) return { picks: [], missing: true };

  const starterPoints = starterPointsByRoster(bundle);
  if (starterPoints.size === 0) return { picks: [], missing: true };

  const scored: PickScore[] = [];
  let usable = false;

  for (const draft of drafts) {
    const picks = allPicks.filter((pick) => pick.draft_id === draft.draft_id);
    if (picks.length === 0) continue;
    // The draft is stored, whether or not it can be ranked.
    usable = true;

    // An auction has no draft position to be a steal relative to — the bid is
    // the price. Ranking one against a snake round would be meaningless.
    if (draft.type === "auction") continue;

    const pointsFor = (pick: PickRow) =>
      pick.player_id && pick.roster_id !== null && pick.roster_id !== undefined
        ? starterPoints.get(`${pick.roster_id}|${pick.player_id}`) ?? 0
        : null;

    const byRound = new Map<number, number[]>();
    for (const pick of picks) {
      const points = pointsFor(pick);
      if (points === null) continue;
      const values = byRound.get(pick.round);
      if (values) values.push(points);
      else byRound.set(pick.round, [points]);
    }
    const everyPick = [...byRound.values()].flat();
    const draftMean = everyPick.length > 0 ? mean(everyPick) : 0;

    // Leave-one-out: a pick is measured against what the *other* picks in its
    // round returned. Including itself would dilute its own verdict — in a
    // 10-team league a steal would eat a tenth of its own surplus.
    const expectedFor = (round: number, points: number) => {
      const values = byRound.get(round);
      if (!values || values.length < 2) return draftMean;
      return (sum(values) - points) / (values.length - 1);
    };

    for (const pick of picks) {
      if (pick.roster_id !== rosterId) continue;
      if (!pick.player_id) continue;
      // A keeper is not a draft decision — a 13th-round keeper "steal" is just
      // a contract, and it would dominate the best-picks list every season.
      if (pick.is_keeper) continue;

      const points = pointsFor(pick) ?? 0;
      const expected = expectedFor(pick.round, points);

      scored.push({
        player_id: pick.player_id,
        player_name: playerName(pick),
        position: pick.metadata?.position ?? null,
        season: draft.season ?? bundle.league.season,
        league_id: bundle.league.league_id,
        league_name: leagueName,
        round: pick.round,
        pick: pick.pick_no,
        draft_slot: pick.draft_slot ?? null,
        points: round2(points),
        expected_points: round2(expected),
        surplus: round2(points - expected),
      });
    }
  }

  return { picks: scored, missing: !usable };
}

/**
 * Points every roster got out of every player it started, for the season.
 *
 * Built for all rosters, not just the user's: the per-round baseline is the
 * rest of the draft, so the other teams' returns are the yardstick.
 */
function starterPointsByRoster(bundle: LeagueBundle): Map<string, number> {
  const totals = new Map<string, number>();
  const lastWeek = lastCountedWeek(bundle.league);

  for (const row of bundle.matchups) {
    if (row.week > lastWeek) continue;
    const points = row.players_points ?? {};

    for (const playerId of row.starters ?? []) {
      // Sleeper writes "0" into a starting slot that was left empty.
      if (!playerId || playerId === "0") continue;
      const scored = Number(points[playerId]);
      if (!Number.isFinite(scored)) continue;

      const key = `${row.roster_id}|${playerId}`;
      totals.set(key, round2((totals.get(key) ?? 0) + scored));
    }
  }

  return totals;
}

function playerName(pick: PickRow): string | null {
  const metadata = pick.metadata ?? {};
  const joined = [metadata.first_name, metadata.last_name]
    .filter((part) => part && part.trim().length > 0)
    .join(" ")
    .trim();
  return joined.length > 0 ? joined : null;
}

function rankPicks(results: LeagueResult[]): CareerDetails["draft"] {
  const picks = results.flatMap((r) => r.picks);

  const best = [...picks].sort((a, b) =>
    b.surplus - a.surplus || b.points - a.points || b.round - a.round
  ).slice(0, TOP_N);

  const worst = [...picks].sort((a, b) =>
    a.surplus - b.surplus || a.points - b.points || a.round - b.round
  ).slice(0, TOP_N);

  return {
    best_picks: best,
    worst_picks: worst,
    scored_picks: picks.length,
    leagues_missing_draft_data: results.filter((r) => r.missingDraftData).length,
  };
}

// ---------------------------------------------------------------------------
// Identity facts
// ---------------------------------------------------------------------------

/**
 * The handful of numbers worth setting in 48pt on the profile.
 *
 * Only facts the data actually supports are returned — an empty slot is better
 * than a zero pretending to be a record.
 */
function buildFacts(
  seasons: SeasonSummary[],
  weeks: WeekResult[],
  regularSeason: RecordSummary,
  playoffs: PlayoffSummary,
  streaks: CareerDetails["streaks"],
): Fact[] {
  const facts: Fact[] = [];
  const seasonCount = new Set(seasons.map((s) => s.season)).size;

  if (seasonCount > 0) {
    facts.push({
      key: "seasons_played",
      label: "Seasons played",
      value: seasonCount,
      unit: "seasons",
    });
  }

  const highest = maxBy(weeks, (w) => w.points);
  if (highest) {
    facts.push({
      key: "highest_week",
      label: "Highest week ever",
      value: highest.points,
      unit: "points",
      season: highest.season,
      week: highest.week,
      league_name: highest.league_name,
      opponent: highest.opponent_name ?? undefined,
    });
  }

  const closest = minBy(
    weeks.filter((w) => w.result === "W" && w.margin !== null),
    (w) => w.margin!,
  );
  if (closest) {
    facts.push({
      key: "closest_win",
      label: "Closest win",
      value: closest.margin!,
      unit: "points",
      season: closest.season,
      week: closest.week,
      league_name: closest.league_name,
      opponent: closest.opponent_name ?? undefined,
      margin: closest.margin!,
    });
  }

  const biggest = maxBy(
    weeks.filter((w) => w.result === "W" && w.margin !== null),
    (w) => w.margin!,
  );
  if (biggest && biggest !== closest) {
    facts.push({
      key: "biggest_win",
      label: "Biggest blowout",
      value: biggest.margin!,
      unit: "points",
      season: biggest.season,
      week: biggest.week,
      league_name: biggest.league_name,
      opponent: biggest.opponent_name ?? undefined,
      margin: biggest.margin!,
    });
  }

  if (playoffs.championships > 0) {
    facts.push({
      key: "championships",
      label: "Championships",
      value: playoffs.championships,
      unit: "count",
    });
  }

  if (streaks.longest_win && streaks.longest_win.length >= 2) {
    facts.push({
      key: "longest_win_streak",
      label: "Longest win streak",
      value: streaks.longest_win.length,
      unit: "games",
      season: streaks.longest_win.season,
      league_name: streaks.longest_win.league_name,
    });
  }

  if (regularSeason.points_for > 0) {
    facts.push({
      key: "points_for",
      label: "Points scored, all time",
      value: regularSeason.points_for,
      unit: "points",
    });
  }

  return facts;
}

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

function numberOrNull(value: number | string | null | undefined): number | null {
  if (value === null || value === undefined || value === "") return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

/** A count column, which Postgres may hand back as a string. */
function whole(value: number | null | undefined): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.trunc(parsed) : 0;
}

function sum(values: number[]): number {
  return values.reduce((total, value) => total + value, 0);
}

function mean(values: number[]): number {
  return values.length === 0 ? 0 : sum(values) / values.length;
}

/** A tie is half a win, the standard fantasy convention. */
function winPct(wins: number, losses: number, ties: number): number | null {
  const games = wins + losses + ties;
  if (games === 0) return null;
  return round2((wins + ties / 2) / games);
}

function maxBy<T>(items: T[], score: (item: T) => number): T | null {
  let best: T | null = null;
  for (const item of items) {
    if (best === null || score(item) > score(best)) best = item;
  }
  return best;
}

function minBy<T>(items: T[], score: (item: T) => number): T | null {
  let best: T | null = null;
  for (const item of items) {
    if (best === null || score(item) < score(best)) best = item;
  }
  return best;
}
