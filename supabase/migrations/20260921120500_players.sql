-- Benchd v1 — the NFL player reference table. Backs player pages and resolves
-- ids found in matchups, draft picks, and news.

create table public.players (
  player_id          text primary key,
  full_name          text,
  first_name         text,
  last_name          text,
  position           text,
  fantasy_positions  text[],
  team               text,
  status             text,
  number             integer,
  age                integer,
  years_exp          integer,

  injury_status      text,
  injury_body_part   text,
  injury_notes       text,
  injury_start_date  date,

  -- Normalized for search: lowercased, with every non-alphanumeric character
  -- removed, so "A.J. Brown", "AJ Brown" and "aj  brown" all collapse to
  -- "ajbrown". GENERATED means it can never drift from full_name.
  --
  -- Every function here is IMMUTABLE, which a generated column requires.
  -- unaccent() is deliberately avoided for that reason — it is only STABLE.
  search_name text generated always as (
    lower(regexp_replace(coalesce(full_name, ''), '[^a-zA-Z0-9]+', '', 'g'))
  ) stored,

  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

comment on table public.players is
  'Synced from Sleeper''s /players/nfl endpoint. That response is ~5MB and
   changes slowly, so it runs on its own schedule — at most daily — rather than
   as part of a user-triggered sync.';

comment on column public.players.status is
  'Sleeper roster status: Active | Inactive | Injured Reserve | ... Free text.';

comment on column public.players.injury_status is
  'Sleeper value: Questionable | Doubtful | Out | IR | null.';

create trigger players_set_updated_at
  before update on public.players
  for each row execute function public.set_updated_at();

-- Indexes --------------------------------------------------------------------

-- Fuzzy / partial player search. Trigram GIN handles both prefix and infix
-- matching, which a plain btree cannot.
create index players_search_name_trgm_idx
  on public.players using gin (search_name extensions.gin_trgm_ops);

-- Position and team filters on the players list.
create index players_position_idx on public.players (position) where position is not null;
create index players_team_idx on public.players (team) where team is not null;

-- "Who is currently injured", for the news and player surfaces.
create index players_injury_status_idx
  on public.players (injury_status)
  where injury_status is not null;

-- RLS ------------------------------------------------------------------------

alter table public.players enable row level security;

create policy "Players are readable by authenticated users"
  on public.players for select to authenticated using (true);
