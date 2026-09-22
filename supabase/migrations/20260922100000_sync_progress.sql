-- Benchd v1 — sync progress and the columns the sync writes into.
--
-- Three additions the original schema did not anticipate. Each is here because
-- a v1 requirement has nowhere else to live:
--
--   1. sync_events      — the first-sync screen surfaces reveals as data lands
--                         ("Found 6 leagues", "Going back to 2019"). That needs
--                         an ordered, readable feed, not a status enum.
--   2. finish_rank      — championships is a headline career stat and the
--                         winners bracket is the only place it comes from.
--   3. last_seen_at     — the hourly cron syncs "accounts active in the last 30
--                         days", which requires an activity signal. Deriving it
--                         from last_synced_at would be circular: syncing an
--                         account would keep it permanently "active".

-- ---------------------------------------------------------------------------
-- profiles.last_seen_at
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column last_seen_at timestamptz not null default now();

comment on column public.profiles.last_seen_at is
  'Touched by the app on launch. The hourly sync uses this to decide which
   accounts are worth refreshing — without it there is no way to stop syncing
   an abandoned account forever.';

create index profiles_last_seen_at_idx on public.profiles (last_seen_at desc);

-- A profile may update its own last_seen_at; the existing owner UPDATE policy
-- already covers this, so no new policy is needed.

-- ---------------------------------------------------------------------------
-- league_members.finish_rank
-- ---------------------------------------------------------------------------

alter table public.league_members
  add column finish_rank integer;

comment on column public.league_members.finish_rank is
  'Final placement from the league''s winners bracket. 1 = champion. Null when
   the season is unfinished or the league had no bracket.';

-- "How many championships does this roster owner have" — the profile headline.
create index league_members_champions_idx
  on public.league_members (sleeper_user_id)
  where finish_rank = 1;

-- ---------------------------------------------------------------------------
-- sleeper_accounts.sync_started_at
-- ---------------------------------------------------------------------------

alter table public.sleeper_accounts
  add column sync_started_at timestamptz;

comment on column public.sleeper_accounts.sync_started_at is
  'When the current run began. Lets the scheduler treat a run that has been
   "syncing" for an implausibly long time as abandoned rather than skipping the
   account forever.';

-- ---------------------------------------------------------------------------
-- sync_events
-- ---------------------------------------------------------------------------

create table public.sync_events (
  id                 bigint generated always as identity primary key,
  sleeper_account_id uuid not null
    references public.sleeper_accounts (id) on delete cascade,
  created_at         timestamptz not null default now(),
  kind               text not null,
  -- Written by the edge function in the voice the UI shows it in. Keeping the
  -- phrasing server-side means a new reveal does not need an app release.
  message            text not null,
  -- { "progress": 0.42, ... } — whatever the specific event carries.
  detail             jsonb not null default '{}'::jsonb
);

comment on table public.sync_events is
  'Append-only progress feed for a sync run, read by the first-sync screen.
   Rows are disposable: a new run clears the previous run''s events.';

comment on column public.sync_events.kind is
  'started | leagues_found | season | league | drafts | bracket | stats |
   completed | failed. Free text so a new reveal needs no migration.';

-- The only query: this account's events, in order, after the last one seen.
create index sync_events_account_id_idx
  on public.sync_events (sleeper_account_id, id);

-- RLS ------------------------------------------------------------------------

alter table public.sync_events enable row level security;

create policy "Sync events are readable by the account owner"
  on public.sync_events for select to authenticated
  using (
    exists (
      select 1
      from public.sleeper_accounts sa
      where sa.id = sync_events.sleeper_account_id
        and sa.profile_id = (select auth.uid())
    )
  );

-- No write policies: only the sync edge function writes here, as service_role.
