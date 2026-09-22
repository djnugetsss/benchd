/**
 * sync-sleeper — pulls one connected Sleeper account's entire history.
 *
 * Walks every season from 2017 (Sleeper's first NFL season) to the current one,
 * follows previous_league_id chains so a league's earlier seasons come along
 * even if the person was not in them under this account, and upserts everything
 * into Postgres.
 *
 * Idempotent by construction: every write is an upsert on a natural key, so
 * running it twice changes nothing. Completed seasons are skipped week-by-week
 * once their matchups are already stored, which is what keeps the hourly cron
 * cheap — a finished 2019 season is never fetched twice.
 *
 * POST { "sleeper_account_id": "<uuid>", "trigger": "app" | "cron" }
 */

import {
  type SleeperBracketEntry,
  SleeperClient,
  type SleeperDraft,
  type SleeperLeague,
  type SleeperLeagueUser,
  type SleeperMatchup,
  type SleeperRoster,
} from "../_shared/sleeper.ts";
import { adminClient, chunk, jsonResponse } from "../_shared/supabase.ts";
import { plural, ProgressReporter } from "../_shared/progress.ts";
import {
  combinePoints,
  currentNFLSeason,
  FIRST_SEASON,
  nullIfZero,
  numberOrNull,
  round2,
  seasonOf,
} from "../_shared/season.ts";
import type { SupabaseClient } from "@supabase/supabase-js";

/** Sleeper's regular season plus the longest plausible playoff run. */
const MAX_WEEK = 18;

/**
 * Wall-clock budget. Edge functions are killed at their platform limit, and a
 * run that dies mid-write leaves sync_status stuck on 'syncing'. Stopping early
 * and reporting partial success is recoverable; being killed is not.
 */
const TIME_BUDGET_MS = 110_000;

interface SyncRequest {
  sleeper_account_id?: string;
  trigger?: string;
}

interface AccountRow {
  id: string;
  sleeper_user_id: string;
  username: string | null;
  display_name: string | null;
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "POST required" }, 405);
  }

  let body: SyncRequest;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: "Body must be JSON" }, 400);
  }

  const accountId = body.sleeper_account_id;
  if (!accountId) {
    return jsonResponse({ error: "sleeper_account_id is required" }, 400);
  }

  const supabase = adminClient();
  const { data: account, error: accountError } = await supabase
    .from("sleeper_accounts")
    .select("id, sleeper_user_id, username, display_name")
    .eq("id", accountId)
    .maybeSingle();

  if (accountError) {
    return jsonResponse({ error: accountError.message }, 500);
  }
  if (!account) {
    return jsonResponse({ error: "No such sleeper_account" }, 404);
  }

  const isCron = body.trigger === "cron";
  const progress = new ProgressReporter(supabase, accountId, !isCron);

  try {
    const summary = await runSync(supabase, account as AccountRow, progress);
    return jsonResponse({ ok: true, ...summary });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("sync-sleeper failed", message);

    await supabase
      .from("sleeper_accounts")
      .update({ sync_status: "failed", sync_error: message })
      .eq("id", accountId);

    await progress.emit("failed", "We couldn't finish the sync.", { error: message });

    return jsonResponse({ ok: false, error: message }, 500);
  }
});

async function runSync(
  supabase: SupabaseClient,
  account: AccountRow,
  progress: ProgressReporter,
) {
  const startedAt = Date.now();
  const sleeper = new SleeperClient();
  const outOfTime = () => Date.now() - startedAt > TIME_BUDGET_MS;

  await supabase
    .from("sleeper_accounts")
    .update({
      sync_status: "syncing",
      sync_started_at: new Date().toISOString(),
      sync_error: null,
    })
    .eq("id", account.id);

  await progress.reset();
  await progress.emit("started", "Looking for your leagues…", { progress: 0.02 });

  // --- 1. Discover every league, across every season -----------------------

  const currentSeason = currentNFLSeason();
  const leagues = new Map<string, SleeperLeague>();

  for (let season = currentSeason; season >= FIRST_SEASON; season--) {
    const seasonLeagues = await sleeper.leaguesForSeason(account.sleeper_user_id, season);
    for (const league of seasonLeagues ?? []) {
      if (!leagues.has(league.league_id)) leagues.set(league.league_id, league);
    }
  }

  // Follow previous_league_id chains. A league discovered in 2024 may point at
  // a 2023 predecessor this account was not a member of under its current
  // roster — following the chain is the only way to reach that history.
  const pending = [...leagues.values()]
    .map((l) => l.previous_league_id)
    .filter((id): id is string => !!id && id !== "0");

  while (pending.length > 0) {
    const previousId = pending.pop()!;
    if (leagues.has(previousId)) continue;

    const league = await sleeper.league(previousId);
    if (!league) continue;

    leagues.set(league.league_id, league);
    if (league.previous_league_id && league.previous_league_id !== "0") {
      pending.push(league.previous_league_id);
    }
  }

  const allLeagues = [...leagues.values()];
  if (allLeagues.length === 0) {
    await finish(supabase, account.id, progress, sleeper, 0);
    await progress.emit(
      "completed",
      "No leagues found for this Sleeper account yet.",
      { progress: 1 },
    );
    return { leagues: 0, calls: sleeper.callCount };
  }

  await progress.emit(
    "leagues_found",
    `Found ${plural(allLeagues.length, "league")}.`,
    { progress: 0.08, leagues: allLeagues.length },
  );

  const seasons = [...new Set(allLeagues.map((l) => seasonOf(l)))].sort();
  if (seasons.length > 0 && seasons[0] < currentSeason) {
    await progress.emit("season", `Going back to ${seasons[0]}.`, {
      progress: 0.1,
      earliest_season: seasons[0],
    });
  }

  // --- 2. Sync each league, newest first ------------------------------------
  // Newest first so the profile has something meaningful on it as early as
  // possible if the budget runs out.

  const ordered = allLeagues.sort((a, b) => seasonOf(b) - seasonOf(a));
  let completed = 0;
  let truncated = false;

  for (const league of ordered) {
    if (outOfTime()) {
      truncated = true;
      break;
    }

    await syncLeague(supabase, sleeper, league, account);
    completed++;

    // 0.10 → 0.92, leaving room for the stats pass at the end.
    const fraction = 0.1 + 0.82 * (completed / ordered.length);
    await progress.emit(
      "league",
      `${seasonOf(league)} — ${league.name ?? "Untitled league"}`,
      { progress: fraction, league_id: league.league_id },
    );
  }

  // --- 3. Recompute the career profile --------------------------------------

  await progress.emit("stats", "Adding up your career…", { progress: 0.95 });
  await recomputeCareerStats(supabase, account);

  await finish(supabase, account.id, progress, sleeper, completed);

  await progress.emit(
    "completed",
    truncated
      ? "Your recent seasons are ready. We'll keep filling in the rest."
      : "Your career is ready.",
    { progress: 1, truncated },
  );

  return {
    leagues: ordered.length,
    synced: completed,
    truncated,
    calls: sleeper.callCount,
  };
}

async function finish(
  supabase: SupabaseClient,
  accountId: string,
  _progress: ProgressReporter,
  _sleeper: SleeperClient,
  _completed: number,
) {
  await supabase
    .from("sleeper_accounts")
    .update({
      sync_status: "synced",
      last_synced_at: new Date().toISOString(),
      sync_error: null,
    })
    .eq("id", accountId);
}

// ---------------------------------------------------------------------------
// One league
// ---------------------------------------------------------------------------

async function syncLeague(
  supabase: SupabaseClient,
  sleeper: SleeperClient,
  league: SleeperLeague,
  account: AccountRow,
) {
  const leagueId = league.league_id;
  const season = seasonOf(league);

  await supabase.from("leagues").upsert({
    league_id: leagueId,
    name: league.name ?? "Untitled league",
    season,
    total_rosters: league.total_rosters ?? null,
    scoring_settings: league.scoring_settings ?? {},
    roster_positions: league.roster_positions ?? null,
    previous_league_id: nullIfZero(league.previous_league_id),
    status: league.status ?? null,
    avatar: league.avatar ?? null,
    settings: league.settings ?? {},
    updated_at: new Date().toISOString(),
  }, { onConflict: "league_id" });

  // --- Rosters and their owners --------------------------------------------

  const [users, rosters] = await Promise.all([
    sleeper.leagueUsers(leagueId),
    sleeper.rosters(leagueId),
  ]);

  const teamNames = new Map<string, string | null>();
  for (const user of users ?? [] as SleeperLeagueUser[]) {
    teamNames.set(user.user_id, user.metadata?.team_name ?? user.display_name ?? null);
  }

  const members = (rosters ?? []).map((roster: SleeperRoster) => ({
    league_id: leagueId,
    roster_id: roster.roster_id,
    sleeper_user_id: roster.owner_id ?? null,
    team_name: roster.owner_id ? teamNames.get(roster.owner_id) ?? null : null,
    co_owner_ids: roster.co_owners ?? null,
    wins: roster.settings?.wins ?? 0,
    losses: roster.settings?.losses ?? 0,
    ties: roster.settings?.ties ?? 0,
    // Sleeper splits points into whole and decimal parts.
    fpts: combinePoints(roster.settings?.fpts, roster.settings?.fpts_decimal),
    fpts_against: combinePoints(
      roster.settings?.fpts_against,
      roster.settings?.fpts_against_decimal,
    ),
    updated_at: new Date().toISOString(),
  }));

  if (members.length > 0) {
    await supabase.from("league_members").upsert(members, {
      onConflict: "league_id,roster_id",
    });
  }

  // --- Matchups -------------------------------------------------------------
  // league_members must exist first: matchups carries a composite FK to it.

  const isComplete = league.status === "complete";
  let storedWeeks = new Set<number>();

  if (isComplete) {
    // The skip that makes the hourly cron cheap. Only worth the extra query for
    // finished seasons — a live one changes every week regardless.
    const { data: existing } = await supabase
      .from("matchups")
      .select("week")
      .eq("league_id", leagueId);
    storedWeeks = new Set((existing ?? []).map((row: { week: number }) => row.week));
  }

  for (let week = 1; week <= MAX_WEEK; week++) {
    if (isComplete && storedWeeks.has(week)) continue;

    const matchups = await sleeper.matchups(leagueId, week);
    if (!matchups || matchups.length === 0) continue;

    const rows = matchups.map((matchup: SleeperMatchup) => ({
      league_id: leagueId,
      week,
      roster_id: matchup.roster_id,
      matchup_id: matchup.matchup_id ?? null,
      points: matchup.points ?? null,
      starters: matchup.starters ?? null,
      players: matchup.players ?? null,
      players_points: matchup.players_points ?? {},
      custom_points: matchup.custom_points ?? null,
      updated_at: new Date().toISOString(),
    }));

    for (const batch of chunk(rows, 200)) {
      await supabase.from("matchups").upsert(batch, {
        onConflict: "league_id,week,roster_id",
      });
    }
  }

  // --- Playoff results ------------------------------------------------------

  await syncWinnersBracket(supabase, sleeper, leagueId);

  // --- Drafts ---------------------------------------------------------------

  await syncDrafts(supabase, sleeper, leagueId, season);

  void account;
}

async function syncWinnersBracket(
  supabase: SupabaseClient,
  sleeper: SleeperClient,
  leagueId: string,
) {
  const bracket = await sleeper.winnersBracket(leagueId);
  if (!bracket || bracket.length === 0) return;

  // `p` is the placement a matchup decides: p=1 is the championship game, so
  // its winner finished 1st and its loser 2nd. Anything without `p` is an
  // earlier round and settles no final position.
  const finishes = new Map<number, number>();

  for (const entry of bracket as SleeperBracketEntry[]) {
    if (!entry.p) continue;
    if (typeof entry.w === "number") finishes.set(entry.w, entry.p);
    if (typeof entry.l === "number") finishes.set(entry.l, entry.p + 1);
  }

  for (const [rosterId, rank] of finishes) {
    await supabase
      .from("league_members")
      .update({ finish_rank: rank })
      .eq("league_id", leagueId)
      .eq("roster_id", rosterId);
  }
}

async function syncDrafts(
  supabase: SupabaseClient,
  sleeper: SleeperClient,
  leagueId: string,
  season: number,
) {
  const drafts = await sleeper.drafts(leagueId);
  if (!drafts || drafts.length === 0) return;

  for (const draft of drafts as SleeperDraft[]) {
    await supabase.from("drafts").upsert({
      draft_id: draft.draft_id,
      league_id: leagueId,
      season: draft.season ? Number(draft.season) : season,
      type: draft.type ?? null,
      status: draft.status ?? null,
      rounds: numberOrNull(draft.settings?.rounds),
      // Sleeper gives start_time in milliseconds since the epoch.
      start_time: draft.start_time ? new Date(draft.start_time).toISOString() : null,
      settings: draft.settings ?? {},
      updated_at: new Date().toISOString(),
    }, { onConflict: "draft_id" });

    const picks = await sleeper.draftPicks(draft.draft_id);
    if (!picks || picks.length === 0) continue;

    const rows = picks.map((pick) => ({
      draft_id: draft.draft_id,
      pick_no: pick.pick_no,
      round: pick.round,
      draft_slot: pick.draft_slot ?? null,
      player_id: pick.player_id ?? null,
      roster_id: pick.roster_id ?? null,
      picked_by: pick.picked_by || null,
      is_keeper: pick.is_keeper ?? false,
      metadata: pick.metadata ?? {},
    }));

    for (const batch of chunk(rows, 300)) {
      await supabase.from("draft_picks").upsert(batch, {
        onConflict: "draft_id,pick_no",
      });
    }
  }
}

// ---------------------------------------------------------------------------
// Career stats
// ---------------------------------------------------------------------------

interface MemberTotals {
  league_id: string;
  wins: number;
  losses: number;
  ties: number;
  fpts: number;
  fpts_against: number;
  finish_rank: number | null;
}

/**
 * Recomputes the cached career profile from what was just written.
 *
 * Reads back from Postgres rather than accumulating in memory, so a partial run
 * still produces a profile consistent with what is actually stored.
 */
async function recomputeCareerStats(supabase: SupabaseClient, account: AccountRow) {
  const { data, error } = await supabase
    .from("league_members")
    .select("league_id, wins, losses, ties, fpts, fpts_against, finish_rank")
    .eq("sleeper_user_id", account.sleeper_user_id);

  if (error) throw error;
  const rows = (data ?? []) as MemberTotals[];

  const leagueIds = rows.map((row) => row.league_id);
  let seasons = 0;
  if (leagueIds.length > 0) {
    const { data: leagueRows } = await supabase
      .from("leagues")
      .select("season")
      .in("league_id", leagueIds);
    seasons = new Set((leagueRows ?? []).map((l: { season: number }) => l.season)).size;
  }

  const totals = rows.reduce(
    (acc, row) => ({
      wins: acc.wins + (row.wins ?? 0),
      losses: acc.losses + (row.losses ?? 0),
      ties: acc.ties + (row.ties ?? 0),
      championships: acc.championships + (row.finish_rank === 1 ? 1 : 0),
      points_for: acc.points_for + Number(row.fpts ?? 0),
      points_against: acc.points_against + Number(row.fpts_against ?? 0),
    }),
    { wins: 0, losses: 0, ties: 0, championships: 0, points_for: 0, points_against: 0 },
  );

  await supabase.from("career_stats").upsert({
    sleeper_account_id: account.id,
    ...totals,
    points_for: round2(totals.points_for),
    points_against: round2(totals.points_against),
    seasons,
    leagues_count: new Set(leagueIds).size,
    details: {},
    computed_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }, { onConflict: "sleeper_account_id" });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Season arithmetic, point recombination, and the other pure helpers live in
 * `_shared/season.ts` so they can be unit tested without importing this module
 * — importing it would start a server.
 */
