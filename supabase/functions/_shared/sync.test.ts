import { assertEquals } from "jsr:@std/assert@1";
import {
  combinePoints,
  currentNFLSeason,
  nullIfZero,
  round2,
  seasonOf,
} from "./season.ts";
import { toRow } from "./players.ts";
import { plural } from "./progress.ts";

Deno.test("currentNFLSeason: August onward is the new season", () => {
  assertEquals(currentNFLSeason(new Date("2026-08-01T00:00:00Z")), 2026);
  assertEquals(currentNFLSeason(new Date("2026-09-22T00:00:00Z")), 2026);
  assertEquals(currentNFLSeason(new Date("2026-12-31T23:59:59Z")), 2026);
});

Deno.test("currentNFLSeason: January to July still belongs to last year", () => {
  // The bug this guards: in February 2027 the 2026 season is still the most
  // recent one. Returning 2027 would make the sync skip it entirely.
  assertEquals(currentNFLSeason(new Date("2027-01-05T00:00:00Z")), 2026);
  assertEquals(currentNFLSeason(new Date("2027-02-28T00:00:00Z")), 2026);
  assertEquals(currentNFLSeason(new Date("2027-07-31T23:59:59Z")), 2026);
});

Deno.test("combinePoints: Sleeper's split whole/decimal points recombine", () => {
  assertEquals(combinePoints(142, 30), 142.3);
  assertEquals(combinePoints(0, 0), 0);
  assertEquals(combinePoints(98, 5), 98.05);
  assertEquals(combinePoints(undefined, undefined), 0);
  assertEquals(combinePoints(120, undefined), 120);
});

Deno.test("round2 keeps two decimals", () => {
  assertEquals(round2(1.005), 1.0);
  assertEquals(round2(1842.556), 1842.56);
});

Deno.test("nullIfZero: Sleeper uses \"0\" to mean no previous league", () => {
  assertEquals(nullIfZero("0"), null);
  assertEquals(nullIfZero(""), null);
  assertEquals(nullIfZero(null), null);
  assertEquals(nullIfZero(undefined), null);
  assertEquals(nullIfZero("784462448236949504"), "784462448236949504");
});

Deno.test("seasonOf falls back rather than producing NaN", () => {
  assertEquals(seasonOf({ league_id: "1", season: "2024" }), 2024);
  assertEquals(seasonOf({ league_id: "1", season: null }), 2017);
  assertEquals(seasonOf({ league_id: "1" }), 2017);
  assertEquals(seasonOf({ league_id: "1", season: "not a year" }), 2017);
});

Deno.test("plural avoids \"1 leagues\"", () => {
  assertEquals(plural(1, "league"), "1 league");
  assertEquals(plural(6, "league"), "6 leagues");
  assertEquals(plural(0, "league"), "0 leagues");
});

Deno.test("toRow: builds a full name when Sleeper omits one", () => {
  const row = toRow("4046", { first_name: "A.J.", last_name: "Brown" });
  assertEquals(row.full_name, "A.J. Brown");
  assertEquals(row.player_id, "4046");
});

Deno.test("toRow: nameless entries are filtered out, not stored blank", () => {
  // Team defences and similar records come back with no name at all.
  const row = toRow("DEF_PHI", { position: "DEF", team: "PHI" });
  assertEquals(row.full_name, null);
});

Deno.test("toRow: an empty injury date becomes null, not \"\"", () => {
  // "" is not a valid Postgres date and would fail the entire 500-row batch.
  assertEquals(toRow("1", { full_name: "X", injury_start_date: "" }).injury_start_date, null);
  assertEquals(toRow("1", { full_name: "X", injury_start_date: "   " }).injury_start_date, null);
  assertEquals(
    toRow("1", { full_name: "X", injury_start_date: "2026-09-01" }).injury_start_date,
    "2026-09-01",
  );
});

Deno.test("toRow never writes the generated search_name column", () => {
  const row = toRow("1", { full_name: "Josh Allen" }) as Record<string, unknown>;
  assertEquals("search_name" in row, false);
});
