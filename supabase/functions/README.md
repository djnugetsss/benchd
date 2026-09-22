# Edge Functions

TypeScript on Deno. One folder per function, each with an `index.ts`.

Create with `supabase functions new <name>` so the scaffolding and import map
match what the CLI expects, then deploy with `supabase functions deploy <name>`.

Secrets (including `SUPABASE_SERVICE_ROLE_KEY` and any news-provider API key) are
set with `supabase secrets set KEY=value` — never committed.

Planned for v1:
- `sync-sleeper` — pull a user's Sleeper leagues, rosters, matchups, and drafts.
- `build-weekly-wrap` — compute top performers for a week and persist the card data.
- `ingest-player-news` — pull the NFL news feed onto player pages.
