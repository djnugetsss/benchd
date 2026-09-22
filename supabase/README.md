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

## Required dashboard setup (auth)

Magic links will not work until this is configured in the Supabase dashboard —
it cannot be done from a migration.

**Authentication → URL Configuration → Redirect URLs**, add:

```
benchd://auth-callback
```

That string appears in exactly two places in the app and both must match it:
`AuthService.redirectURL`, and `CFBundleURLTypes` in
`Benchd/Resources/Info.plist`. If the dashboard does not list it, Supabase sends
people to the site URL instead and the app never receives the token.

Email magic link is the only sign-in method in v1 — no passwords, no Sign in
with Apple — so **Authentication → Providers → Email** must stay enabled.

## Sync architecture

Two functions, two cadences. Neither is real-time, by design.

| Function | Trigger | Cadence |
|---|---|---|
| `sync-players` | pg_cron | Daily, 09:40 UTC — Sleeper asks for at most once a day on `/players/nfl` (~5MB) |
| `sync-sleeper` | pg_cron, and the app after a connect | Hourly at :20, only for accounts whose owner opened the app in the last 30 days |

**Idempotency.** Every write is an upsert on a natural key, so a re-run changes
nothing. For leagues whose season is `complete`, weeks already present in
`matchups` are not re-fetched — that is what keeps the hourly job cheap once a
history has landed.

**Rate limiting.** `SleeperClient` paces itself to one call per 120ms (~500/min
per instance, half of Sleeper's stated ceiling) and backs off on 429/5xx. The
scheduler caps each hourly tick at 200 accounts so it cannot release a stampede.

**Time budget.** `sync-sleeper` stops at 110s and reports partial success rather
than being killed mid-write. Leagues are synced newest-first so a truncated run
still leaves a useful profile, and the next run picks up the rest.

**Progress.** The function writes to `sync_events`; the first-sync screen polls
it. Cron runs write no events — nobody is watching, and an hourly refresh would
bury the feed.

### Deploying

**`supabase db push` alone is not enough.** The database and the functions
deploy separately, and a project with migrations applied but no functions looks
healthy right up until the app calls one and gets a 404 in 9ms. Both steps, plus
the Vault secrets, or the sync silently never runs:

```bash
supabase functions deploy sync-sleeper
supabase functions deploy sync-players
supabase db push                          # includes the pg_cron schedule
```

Then the one-time Vault setup in
`supabase/migrations/20260922100100_scheduled_sync.sql`. Until those two secrets
exist, the cron jobs raise a clear error rather than failing silently.

### Testing the functions

```bash
cd supabase/functions
deno check --no-config sync-sleeper/index.ts sync-players/index.ts
deno test  --no-config --allow-net --allow-env _shared/sync.test.ts
```

**Use `--no-config`.** Every import is an explicit `npm:` or `jsr:` specifier,
and there is deliberately no import map — `supabase functions deploy` does not
apply one, so a local check that relies on an import map can pass against a
configuration the deploy never sees. `--no-config` reproduces deploy conditions.

`deno.json` holds lint and format settings only. Do not add an `imports` block
to it.

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
