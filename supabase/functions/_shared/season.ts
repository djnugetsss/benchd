import type { SleeperLeague } from "./sleeper.ts";

/** Sleeper's first NFL season. There is nothing before this to find. */
export const FIRST_SEASON = 2017;

/**
 * The NFL season a date belongs to.
 *
 * A season is named for the calendar year it starts in, so January–July still
 * belongs to the previous year's season. Getting this wrong would make the sync
 * skip the most recent season for seven months of every year.
 */
export function currentNFLSeason(now: Date = new Date()): number {
  const year = now.getUTCFullYear();
  return now.getUTCMonth() >= 7 ? year : year - 1;
}

/** A league's season, falling back rather than producing NaN. */
export function seasonOf(league: SleeperLeague): number {
  const parsed = Number(league.season);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : FIRST_SEASON;
}

/** Sleeper stores points as a whole part plus a separate decimal part. */
export function combinePoints(whole?: number, decimal?: number): number {
  return round2((whole ?? 0) + (decimal ?? 0) / 100);
}

export function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

/** Sleeper uses the string "0" to mean "no previous league". */
export function nullIfZero(value?: string | null): string | null {
  return !value || value === "0" ? null : value;
}

export function numberOrNull(value: unknown): number | null {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}
