/**
 * sync-players — refreshes the NFL player reference table.
 *
 * GET /players/nfl returns every player Sleeper knows about as one object of
 * ~5MB. Sleeper explicitly asks callers not to fetch it more than once a day,
 * which is why this is a separate function on its own daily schedule rather
 * than part of an account sync.
 *
 * POST {} — no arguments. Scheduled by pg_cron; see
 * supabase/migrations/20260922100100_scheduled_sync.sql.
 */

import { SleeperClient } from "../_shared/sleeper.ts";
import { toRow } from "../_shared/players.ts";
import { adminClient, chunk, jsonResponse } from "../_shared/supabase.ts";

/**
 * Rows per upsert. ~11k players at once would exceed the statement and payload
 * limits; 500 keeps each request comfortably small without making the whole
 * refresh a long sequence of round trips.
 */
const BATCH_SIZE = 500;

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "POST required" }, 405);
  }

  const supabase = adminClient();
  const sleeper = new SleeperClient();

  try {
    const players = await sleeper.allPlayers();
    if (!players) {
      return jsonResponse({ error: "Sleeper returned no players" }, 502);
    }

    const rows = Object.entries(players)
      .map(([playerId, player]) => toRow(playerId, player))
      // Sleeper's payload includes team defence entries and other records with
      // no usable name. They are not players and would clutter search.
      .filter((row) => row.full_name !== null);

    let written = 0;
    for (const batch of chunk(rows, BATCH_SIZE)) {
      const { error } = await supabase
        .from("players")
        .upsert(batch, { onConflict: "player_id" });

      if (error) throw new Error(`players upsert failed: ${error.message}`);
      written += batch.length;
    }

    // Deliberately no delete pass: a player who leaves the league still appears
    // in old matchups and draft picks, and removing the row would orphan every
    // reference to them.
    console.log(`sync-players: upserted ${written} of ${rows.length}`);

    return jsonResponse({
      ok: true,
      received: Object.keys(players).length,
      written,
      calls: sleeper.callCount,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("sync-players failed", message);
    return jsonResponse({ ok: false, error: message }, 500);
  }
});

