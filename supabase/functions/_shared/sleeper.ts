/**
 * Read-only client for Sleeper's public API.
 *
 * Sleeper documents a ceiling of 1000 calls per minute and asks callers to stay
 * well under it. A full history sync for one account is easily several hundred
 * calls, and the hourly cron can start many of them at once, so pacing is not
 * optional — it is the difference between a working sync and a blocked IP.
 */

const BASE_URL = "https://api.sleeper.app/v1";

/**
 * Minimum gap between requests, in ms. 120ms caps a single function instance at
 * ~500 calls/minute — half of Sleeper's ceiling, leaving room for the other
 * instances the hourly scheduler may have started.
 */
const MIN_REQUEST_INTERVAL_MS = 120;

const MAX_ATTEMPTS = 3;

export class SleeperNotFoundError extends Error {
  constructor(path: string) {
    super(`Sleeper has no resource at ${path}`);
    this.name = "SleeperNotFoundError";
  }
}

export class SleeperUnavailableError extends Error {
  constructor(path: string, status: number) {
    super(`Sleeper returned ${status} for ${path}`);
    this.name = "SleeperUnavailableError";
  }
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

export class SleeperClient {
  #lastRequestAt = 0;
  #callCount = 0;

  /** How many HTTP calls this instance has made. Reported in the sync summary. */
  get callCount(): number {
    return this.#callCount;
  }

  async #pace(): Promise<void> {
    const elapsed = Date.now() - this.#lastRequestAt;
    if (elapsed < MIN_REQUEST_INTERVAL_MS) {
      await sleep(MIN_REQUEST_INTERVAL_MS - elapsed);
    }
    this.#lastRequestAt = Date.now();
  }

  /**
   * GET a path under the API base.
   *
   * Returns `null` for a missing resource rather than throwing, because Sleeper
   * uses "absent" as a normal answer in several places — a league with no
   * drafts, a week with no matchups, an unknown user. Callers that genuinely
   * cannot proceed without the resource check for null themselves.
   */
  async get<T>(path: string): Promise<T | null> {
    let lastError: unknown;

    for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
      await this.#pace();
      this.#callCount++;

      try {
        const response = await fetch(`${BASE_URL}${path}`, {
          headers: { "Accept": "application/json" },
        });

        if (response.status === 404) {
          // Drain the body so the connection can be reused.
          await response.body?.cancel();
          return null;
        }

        if (response.status === 429 || response.status >= 500) {
          await response.body?.cancel();
          lastError = new SleeperUnavailableError(path, response.status);
          // Exponential backoff: 500ms, 1500ms. Rate limiting is the one error
          // worth waiting out rather than failing fast on.
          await sleep(500 * Math.pow(3, attempt - 1));
          continue;
        }

        if (!response.ok) {
          await response.body?.cancel();
          throw new SleeperUnavailableError(path, response.status);
        }

        const text = await response.text();
        // Sleeper answers "not found" on several endpoints with HTTP 200 and a
        // body of literally `null`. Treated the same as a 404.
        if (text.trim() === "" || text.trim() === "null") return null;

        return JSON.parse(text) as T;
      } catch (error) {
        lastError = error;
        if (attempt === MAX_ATTEMPTS) break;
        await sleep(500 * attempt);
      }
    }

    throw lastError ?? new SleeperUnavailableError(path, 0);
  }

  // --- Endpoints used by the sync ------------------------------------------

  leaguesForSeason(userId: string, season: number) {
    return this.get<SleeperLeague[]>(`/user/${userId}/leagues/nfl/${season}`);
  }

  league(leagueId: string) {
    return this.get<SleeperLeague>(`/league/${leagueId}`);
  }

  leagueUsers(leagueId: string) {
    return this.get<SleeperLeagueUser[]>(`/league/${leagueId}/users`);
  }

  rosters(leagueId: string) {
    return this.get<SleeperRoster[]>(`/league/${leagueId}/rosters`);
  }

  matchups(leagueId: string, week: number) {
    return this.get<SleeperMatchup[]>(`/league/${leagueId}/matchups/${week}`);
  }

  winnersBracket(leagueId: string) {
    return this.get<SleeperBracketEntry[]>(`/league/${leagueId}/winners_bracket`);
  }

  drafts(leagueId: string) {
    return this.get<SleeperDraft[]>(`/league/${leagueId}/drafts`);
  }

  draftPicks(draftId: string) {
    return this.get<SleeperDraftPick[]>(`/draft/${draftId}/picks`);
  }

  allPlayers() {
    return this.get<Record<string, SleeperPlayer>>("/players/nfl");
  }
}

// --- Wire shapes ------------------------------------------------------------
// Only the fields the sync actually reads. Sleeper returns a great deal more.

export interface SleeperLeague {
  league_id: string;
  name?: string | null;
  season?: string | null;
  total_rosters?: number | null;
  scoring_settings?: Record<string, number> | null;
  roster_positions?: string[] | null;
  previous_league_id?: string | null;
  status?: string | null;
  avatar?: string | null;
  settings?: Record<string, unknown> | null;
}

export interface SleeperLeagueUser {
  user_id: string;
  display_name?: string | null;
  metadata?: { team_name?: string | null } | null;
}

export interface SleeperRoster {
  roster_id: number;
  owner_id?: string | null;
  co_owners?: string[] | null;
  settings?: {
    wins?: number;
    losses?: number;
    ties?: number;
    fpts?: number;
    fpts_decimal?: number;
    fpts_against?: number;
    fpts_against_decimal?: number;
  } | null;
}

export interface SleeperMatchup {
  roster_id: number;
  matchup_id?: number | null;
  points?: number | null;
  custom_points?: number | null;
  starters?: string[] | null;
  players?: string[] | null;
  players_points?: Record<string, number> | null;
}

export interface SleeperBracketEntry {
  r?: number | null;
  m?: number | null;
  t1?: number | null;
  t2?: number | null;
  w?: number | null;
  l?: number | null;
  /** Placement this matchup decides: 1 = championship, 3 = third place, … */
  p?: number | null;
}

export interface SleeperDraft {
  draft_id: string;
  league_id?: string | null;
  season?: string | null;
  type?: string | null;
  status?: string | null;
  start_time?: number | null;
  settings?: Record<string, unknown> | null;
}

export interface SleeperDraftPick {
  draft_id?: string | null;
  pick_no: number;
  round: number;
  draft_slot?: number | null;
  player_id?: string | null;
  roster_id?: number | null;
  picked_by?: string | null;
  is_keeper?: boolean | null;
  metadata?: Record<string, string> | null;
}

export interface SleeperPlayer {
  player_id?: string | null;
  full_name?: string | null;
  first_name?: string | null;
  last_name?: string | null;
  position?: string | null;
  fantasy_positions?: string[] | null;
  team?: string | null;
  status?: string | null;
  number?: number | null;
  age?: number | null;
  years_exp?: number | null;
  injury_status?: string | null;
  injury_body_part?: string | null;
  injury_notes?: string | null;
  injury_start_date?: string | null;
}
