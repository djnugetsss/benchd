-- Benchd v1 — leagues and their rosters.
--
-- Everything below is synced from Sleeper's public, read-only API by an edge
-- function running as service_role. Authenticated users have SELECT only.

create table public.leagues (
  league_id           text primary key,
  name                text not null,
  season              integer not null,
  total_rosters       integer,
  scoring_settings    jsonb not null default '{}'::jsonb,
  roster_positions    text[],
  previous_league_id  text,
  status              text,
  avatar              text,
  settings            jsonb not null default '{}'::jsonb,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

comment on table public.leagues is
  'Sleeper league. Keyed on Sleeper''s own league_id rather than a surrogate
   uuid, so the sync path never needs a lookup to resolve a foreign key.';

comment on column public.leagues.previous_league_id is
  'Sleeper''s link to the prior season of the same league. Intentionally NOT a
   self-referencing FK: a user may connect a 2024 league whose 2023 predecessor
   was never synced, and a real FK would reject that row.';

comment on column public.leagues.status is
  'Sleeper value: pre_draft | drafting | in_season | complete. Stored as free
   text, not an enum or CHECK, so a new Sleeper value cannot break a sync.';

comment on column public.leagues.scoring_settings is
  'Sleeper scoring_settings: a flat object of scoring key -> points.';

create trigger leagues_set_updated_at
  before update on public.leagues
  for each row execute function public.set_updated_at();

create index leagues_season_idx on public.leagues (season desc);
create index leagues_previous_league_id_idx
  on public.leagues (previous_league_id)
  where previous_league_id is not null;

-- ---------------------------------------------------------------------------
-- league_members
-- ---------------------------------------------------------------------------

create table public.league_members (
  league_id        text    not null references public.leagues (league_id) on delete cascade,
  roster_id        integer not null,
  sleeper_user_id  text,
  team_name        text,
  co_owner_ids     text[],

  -- Season totals straight from Sleeper's roster settings. These are the
  -- primary input to career_stats; deriving them from matchups instead would
  -- be both slower and wrong for seasons whose matchups predate a connection.
  wins             integer not null default 0,
  losses           integer not null default 0,
  ties             integer not null default 0,
  fpts             numeric(10, 2) not null default 0,
  fpts_against     numeric(10, 2) not null default 0,

  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),

  primary key (league_id, roster_id)
);

comment on table public.league_members is
  'One row per roster in a league. sleeper_user_id is nullable because Sleeper
   allows orphaned rosters (a team with no manager). It is a raw Sleeper id and
   deliberately NOT a FK to sleeper_accounts: most league members are not Benchd
   users, and never will be.';

create trigger league_members_set_updated_at
  before update on public.league_members
  for each row execute function public.set_updated_at();

-- The hot path for building a career profile: every roster this Sleeper user
-- has ever owned, across every league.
create index league_members_sleeper_user_id_idx
  on public.league_members (sleeper_user_id)
  where sleeper_user_id is not null;

-- RLS ------------------------------------------------------------------------
--
-- Reference data: readable by any authenticated user, written only by the
-- service role. service_role bypasses RLS entirely in Supabase, so the absence
-- of INSERT/UPDATE/DELETE policies is what locks writes to edge functions —
-- there is deliberately no write policy to find here.
--
-- `using (true)` on SELECT is a DELIBERATE, reviewed decision, not an oversight:
-- any authenticated user can read any league, including leagues they are not a
-- member of. It is acceptable because every row here is mirrored from Sleeper's
-- public, unauthenticated API — we expose nothing Sleeper does not already serve
-- to anyone who knows the league_id.
--
-- If that ever stops being true (a private league source, or user-authored
-- content on these tables), this policy must be narrowed to leagues the caller
-- belongs to, via league_members -> sleeper_accounts -> auth.uid().

alter table public.leagues enable row level security;
alter table public.league_members enable row level security;

create policy "Leagues are readable by authenticated users"
  on public.leagues for select to authenticated using (true);

create policy "League members are readable by authenticated users"
  on public.league_members for select to authenticated using (true);
