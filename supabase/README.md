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
