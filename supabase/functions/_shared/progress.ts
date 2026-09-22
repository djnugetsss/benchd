import type { SupabaseClient } from "@supabase/supabase-js";

/**
 * Writes the reveal feed the first-sync screen reads.
 *
 * Messages are composed here rather than in the app so a new reveal does not
 * need an App Store release. They are written in the app's voice — calm, plain,
 * never a percentage read aloud.
 */
export class ProgressReporter {
  #client: SupabaseClient;
  #accountId: string;
  #enabled: boolean;

  constructor(client: SupabaseClient, accountId: string, enabled = true) {
    this.#client = client;
    this.#accountId = accountId;
    // Cron runs write no reveals: nobody is watching, and an hourly refresh
    // would otherwise bury the first-sync feed under thousands of rows.
    this.#enabled = enabled;
  }

  /** Clears the previous run's feed so the screen starts from empty. */
  async reset(): Promise<void> {
    if (!this.#enabled) return;
    await this.#client
      .from("sync_events")
      .delete()
      .eq("sleeper_account_id", this.#accountId);
  }

  async emit(
    kind: string,
    message: string,
    detail: Record<string, unknown> = {},
  ): Promise<void> {
    if (!this.#enabled) return;
    // Progress reporting must never be able to fail a sync — a dropped reveal
    // is cosmetic, a thrown error here would lose real data.
    try {
      await this.#client.from("sync_events").insert({
        sleeper_account_id: this.#accountId,
        kind,
        message,
        detail,
      });
    } catch (error) {
      console.error("progress emit failed (ignored)", error);
    }
  }
}

/** "1 league" / "6 leagues" — avoids "1 leagues" in the reveal feed. */
export function plural(count: number, singular: string, pluralForm?: string): string {
  return `${count} ${count === 1 ? singular : pluralForm ?? `${singular}s`}`;
}
