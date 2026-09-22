import type { SleeperPlayer } from "./sleeper.ts";

/**
 * Maps one entry of Sleeper's /players/nfl payload onto a `players` row.
 *
 * Never writes `search_name` — that column is GENERATED in Postgres and an
 * explicit value would be rejected.
 */
export function toRow(playerId: string, player: SleeperPlayer) {
  const fullName = player.full_name?.trim() ||
    [player.first_name, player.last_name].filter(Boolean).join(" ").trim();

  return {
    player_id: playerId,
    full_name: fullName || null,
    first_name: player.first_name ?? null,
    last_name: player.last_name ?? null,
    position: player.position ?? null,
    fantasy_positions: player.fantasy_positions ?? null,
    team: player.team ?? null,
    status: player.status ?? null,
    number: player.number ?? null,
    age: player.age ?? null,
    years_exp: player.years_exp ?? null,
    injury_status: player.injury_status ?? null,
    injury_body_part: player.injury_body_part ?? null,
    injury_notes: player.injury_notes ?? null,
    // A Postgres `date` column: an empty string is not a valid date and would
    // fail the whole 500-row batch, so it has to become null here.
    injury_start_date: player.injury_start_date?.trim() || null,
    updated_at: new Date().toISOString(),
  };
}
