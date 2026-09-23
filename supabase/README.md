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

**Time budget.** `sync-sleeper` stops fetching leagues at 95s — leaving headroom
for the career stats pass that follows it — and reports partial success rather
than being killed mid-write. Leagues are synced newest-first so a truncated run
still leaves a useful profile, and the next run picks up the rest.

**Progress.** The function writes to `sync_events`; the first-sync screen polls
it. Cron runs write no events — nobody is watching, and an hourly refresh would
bury the feed.

### Career stats

`sync-sleeper` finishes by rebuilding `career_stats` for the account. The
arithmetic lives in `_shared/career.ts` — pure functions over rows, no network,
no clock, no Supabase client — so it is unit tested against fixtures in
`_shared/career.test.ts`. The edge function only gathers rows and upserts the
result, and it reads them back out of Postgres rather than accumulating during
the sync, so a run that stopped at its time budget still produces a profile
consistent with what actually landed. Rebuilding a profile is therefore one call
to `recomputeCareerStats`, and `career_stats` stays safe to truncate.

The promoted columns (`wins`, `losses`, `ties`, `points_for`, `points_against`)
are the **regular season**, which is what Sleeper's own roster record means and
what a user recognises as "my record". Playoffs, streaks, the per-season
timeline, draft grades, rivalries and the featured facts are in `details`, under
a `version` the app can check.

Five things there are easy to get wrong, each handled explicitly and covered by
a test:

| Case | What the code does |
|---|---|
| Weeks not yet played | Sleeper answers for every week of a live league with zeroes. A week counts only if somebody scored, and `settings.leg` excludes the week in progress — a partial score is not a result |
| Median scoring | `league_average_match` settles two results a week. The extra result counts in the record; the median is *not* added to points against, because it is a threshold, not a team |
| Playoffs vs consolation | Playoff-week rows in `matchups` contain both brackets. The playoff record comes from `leagues.winners_bracket`, falling back to `finish_rank` for the title alone |
| Draft grades | A pick is worth what it scored **in that roster's starting lineup that season**, measured against what the other picks in the same round of the same draft returned. Keepers and auctions are excluded — neither is a draft-position call |
| Rosters vs people | Rivalries are keyed on `sleeper_user_id`, so a rival is still the same rival after the league rolls over and the roster numbers change. Ownership beats co-ownership. A roster that changed hands mid-season is attributed to its current owner — Sleeper reports no history for it |

Streaks are computed within one league-season. Someone in three leagues at once
plays three parallel schedules, and interleaving them by week would manufacture
a streak out of games from different competitions.

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
deno test  --no-config _shared/career.test.ts
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
| `leagues.winners_bracket` | A playoff record cannot be recovered from playoff-week matchups, which also hold the consolation bracket |
| `league_members.wins/losses/ties/fpts/fpts_against` | Free from Sleeper's rosters endpoint. The career computation derives the record from `matchups` instead — streaks, rivalries and per-week facts need the weeks anyway — and falls back to these totals for a league-season whose matchups have not landed yet |
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
