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
