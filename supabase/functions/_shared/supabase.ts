import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

/**
 * Service-role client. Bypasses RLS, which is exactly why every table in this
 * schema has no write policies: the sync is the only writer, and it runs here.
 *
 * These two variables are injected into every edge function by the platform —
 * they are not the app's anon key and must never be returned to a client.
 */
export function adminClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!url || !serviceKey) {
    throw new Error(
      "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in the function environment",
    );
  }

  return createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export const jsonResponse = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

/** Splits an array into fixed-size chunks, for batched upserts. */
export function chunk<T>(items: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < items.length; i += size) {
    chunks.push(items.slice(i, i + size));
  }
  return chunks;
}

/**
 * Reads every row of a query, a page at a time.
 *
 * PostgREST caps a response at its configured maximum — 1000 rows by default —
 * and says nothing when it truncates. A single league-season is a few hundred
 * matchup rows, so a career easily crosses that line: without paging, the
 * career stats would silently be computed from the first 1000 rows and the
 * oldest seasons would quietly vanish.
 *
 * The filter builder is consumed lazily by `.range()`, so pass a freshly built
 * query, not one that has already been awaited.
 */
export async function selectAll<T>(
  // deno-lint-ignore no-explicit-any
  query: any,
  pageSize = 1000,
): Promise<T[]> {
  const rows: T[] = [];

  for (let from = 0;; from += pageSize) {
    const { data, error } = await query.range(from, from + pageSize - 1);
    if (error) throw error;

    const page = (data ?? []) as T[];
    rows.push(...page);
    if (page.length < pageSize) break;
  }

  return rows;
}
