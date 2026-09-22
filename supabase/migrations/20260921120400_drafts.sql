-- Benchd v1 — drafts and picks. The source of "best and worst draft pick".

create table public.drafts (
  draft_id    text primary key,
  league_id   text not null references public.leagues (league_id) on delete cascade,
  season      integer not null,
  type        text,
  status      text,
  rounds      integer,
  start_time  timestamptz,
  settings    jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on column public.drafts.type is
  'Sleeper value: snake | linear | auction. Free text for the same reason as
   leagues.status — Sleeper owns this vocabulary, not us.';

create trigger drafts_set_updated_at
  before update on public.drafts
  for each row execute function public.set_updated_at();

create index drafts_league_id_idx on public.drafts (league_id);

-- ---------------------------------------------------------------------------
-- draft_picks
-- ---------------------------------------------------------------------------

create table public.draft_picks (
  draft_id    text    not null references public.drafts (draft_id) on delete cascade,
  pick_no     integer not null,
  round       integer not null,
  draft_slot  integer,
  player_id   text,
  roster_id   integer,
  picked_by   text,
  is_keeper   boolean not null default false,
  metadata    jsonb   not null default '{}'::jsonb,
  created_at  timestamptz not null default now(),

  primary key (draft_id, pick_no)
);

comment on table public.draft_picks is
  'One row per pick. pick_no is unique within a draft and is Sleeper''s overall
   pick number, so (draft_id, pick_no) is the natural key.';

comment on column public.draft_picks.player_id is
  'Sleeper player_id. Deliberately NOT a FK to players: the players table is
   synced on its own schedule from a separate ~5MB endpoint, and a FK would make
   a draft sync fail whenever Sleeper adds a player we have not pulled yet.
   Resolve with a LEFT JOIN and treat a miss as "unknown player".';

comment on column public.draft_picks.roster_id is
  'Nullable, and intentionally not a composite FK to league_members: offseason
   and keeper drafts can carry picks with no roster assigned yet.';

-- Indexes --------------------------------------------------------------------

create index draft_picks_player_id_idx
  on public.draft_picks (player_id)
  where player_id is not null;

create index draft_picks_roster_idx
  on public.draft_picks (draft_id, roster_id)
  where roster_id is not null;

create index draft_picks_picked_by_idx
  on public.draft_picks (picked_by)
  where picked_by is not null;

-- RLS ------------------------------------------------------------------------

alter table public.drafts enable row level security;
alter table public.draft_picks enable row level security;

create policy "Drafts are readable by authenticated users"
  on public.drafts for select to authenticated using (true);

create policy "Draft picks are readable by authenticated users"
  on public.draft_picks for select to authenticated using (true);
