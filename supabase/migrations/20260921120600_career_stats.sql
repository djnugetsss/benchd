-- Benchd v1 — the precomputed career profile.
--
-- Recomputed by an edge function after each successful Sleeper sync. This is a
-- cache: every value here is derivable from league_members, matchups, and
-- draft_picks, and the table can be truncated and rebuilt at any time.

create table public.career_stats (
  sleeper_account_id uuid primary key
    references public.sleeper_accounts (id) on delete cascade,

  -- Promoted to real columns because they are the headline numbers on the
  -- profile screen: they need to sort, filter, and index.
  wins           integer not null default 0,
  losses         integer not null default 0,
  ties           integer not null default 0,
  championships  integer not null default 0,
  seasons        integer not null default 0,
  leagues_count  integer not null default 0,
  points_for     numeric(12, 2) not null default 0,
  points_against numeric(12, 2) not null default 0,

  -- Everything else: best/worst draft picks, rivalries, streaks, per-season
  -- breakdowns. Kept as jsonb so the shape can evolve with the wrap cards
  -- without a migration for every new derived stat.
  details        jsonb not null default '{}'::jsonb,

  computed_at    timestamptz not null default now(),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),

  constraint career_stats_counts_nonnegative check (
    wins >= 0 and losses >= 0 and ties >= 0
    and championships >= 0 and seasons >= 0 and leagues_count >= 0
  )
);

comment on table public.career_stats is
  'One row per connected Sleeper account. A derived cache, not a source of
   truth — safe to delete and rebuild.';

create trigger career_stats_set_updated_at
  before update on public.career_stats
  for each row execute function public.set_updated_at();

-- RLS ------------------------------------------------------------------------
--
-- Unlike the reference tables, this is personal data: it is scoped to the
-- owner of the underlying Sleeper account, reached through sleeper_accounts.

alter table public.career_stats enable row level security;

create policy "Career stats are readable by the account owner"
  on public.career_stats for select to authenticated
  using (
    exists (
      select 1
      from public.sleeper_accounts sa
      where sa.id = career_stats.sleeper_account_id
        and sa.profile_id = (select auth.uid())
    )
  );

-- No write policies: career_stats is only ever written by the edge function
-- that computes it, running as service_role.
