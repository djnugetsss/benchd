-- Benchd v1 — weekly matchups. The input to the weekly wrap cards.

create table public.matchups (
  league_id      text    not null,
  week           integer not null,
  roster_id      integer not null,

  -- Sleeper groups the two sides of a head-to-head by a shared matchup_id.
  -- Nullable: byes and some offseason weeks come back without one.
  matchup_id     integer,

  points         numeric(10, 2),
  starters       text[],

  -- Full roster for the week. Not in the original column list, but bench points
  -- cannot be computed from starters alone, and "what you left on the bench" is
  -- exactly the kind of stat the wrap cards are built on.
  players        text[],

  players_points jsonb not null default '{}'::jsonb,
  custom_points  numeric(10, 2),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),

  primary key (league_id, week, roster_id),

  -- Composite FK to the roster, not just the league. A matchup for a roster
  -- that does not exist in the league is always a sync bug, and this makes it
  -- impossible to persist one.
  constraint matchups_roster_fkey
    foreign key (league_id, roster_id)
    references public.league_members (league_id, roster_id)
    on delete cascade
);

comment on table public.matchups is
  'One row per roster per week. Synced from Sleeper by an edge function.';

comment on column public.matchups.players_points is
  'Object of Sleeper player_id -> points scored that week.';

create trigger matchups_set_updated_at
  before update on public.matchups
  for each row execute function public.set_updated_at();

-- Indexes --------------------------------------------------------------------

-- "Top performers in week N", the weekly wrap query.
create index matchups_league_week_idx on public.matchups (league_id, week);

-- Pairing the two sides of a head-to-head.
create index matchups_pairing_idx
  on public.matchups (league_id, week, matchup_id)
  where matchup_id is not null;

-- The composite PK already covers (league_id, roster_id) lookups, so the
-- composite FK above needs no extra index.

-- RLS ------------------------------------------------------------------------

alter table public.matchups enable row level security;

create policy "Matchups are readable by authenticated users"
  on public.matchups for select to authenticated using (true);
