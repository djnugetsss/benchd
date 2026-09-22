# Supabase

Backend for Benchd: Postgres + Auth + Storage, with server-side logic as Edge
Functions written in TypeScript on Deno.

```
supabase/
  config.toml     created by `supabase init`
  migrations/     SQL schema history, applied in filename order
  functions/      Edge Functions (TypeScript / Deno)
```

## Rules

- **Every table has Row Level Security enabled.** The app ships the anon key, so
  RLS is the only thing standing between a user and everyone else's data. A
  migration that creates a table without `enable row level security` is incomplete.
- **Schema changes are migrations.** Never click through the dashboard SQL editor
  for something that needs to exist on another machine. Author locally with
  `supabase db diff -f <name>`, review the SQL, commit it.
- **The `service_role` key never leaves the server.** It belongs in Edge Function
  secrets, never in `Secrets.xcconfig` and never in the app.
- Syncing is periodic, not real-time: Sleeper pulls run on a schedule or a manual
  refresh, from an Edge Function — not from the client on a timer.

## Confirmed design decisions

These were raised explicitly and signed off. Do not quietly reverse them; if one
needs to change, change it deliberately and update this list.

**1. Profiles are private — own row only.**
`public.profiles` has no cross-user read policy. A user can see only their own
row. This is correct for v1, which has no social graph. *v2 implication:* the
feed and following features cannot work without adding a read policy here, and
that policy is a privacy decision worth its own review — it should not be
bolted on as part of a feature PR.

**2. League, matchup, draft, player, and news data is readable by every
authenticated user.**
`using (true)` on those SELECT policies is intentional. Every row is mirrored
from Sleeper's public, unauthenticated API, so we expose nothing Sleeper does
not already serve to anyone holding a `league_id`. *Revisit the moment* a
private data source or any user-authored content lands on these tables — see
the comment in `20260921120200_leagues.sql`.

**3. Several columns exist beyond the original spec**, each earning its place:

| Column | Why |
|---|---|
| `matchups.players` | Bench points are uncomputable from `starters` alone, and "what you left on the bench" is core wrap-card material |
| `league_members.wins/losses/ties/fpts/fpts_against` | Free from Sleeper's rosters endpoint and the primary input to `career_stats`; deriving from matchups would be slower and wrong for seasons predating a connection |
| `sleeper_accounts.sync_error` | Surfacing *why* a sync failed |
| `leagues.roster_positions/settings/avatar` | Returned by Sleeper, needed for league display |
| `draft_picks.metadata` | Sleeper's all-string pick payload |
| `news_items.image_url` | Story artwork |
| `career_stats.seasons/leagues_count/points_for/points_against` | Headline profile numbers that need to sort and index |

Also settled: `service_role` bypasses RLS, so the **absence** of write policies
on reference tables is what restricts writes to edge functions. There is no
write policy to find, by design.

## Commands

```bash
supabase start                    # local stack (Docker required)
supabase status                   # local URLs + keys
supabase db diff -f add_profiles  # author a migration from local schema drift
supabase db reset                 # rebuild local db from migrations/
supabase functions new sync-sleeper
supabase functions serve          # run functions locally
supabase link --project-ref <ref> # connect to the hosted project
supabase db push                  # apply migrations to the hosted project
supabase stop
```
