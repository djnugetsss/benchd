-- Benchd v1 — player news. Read-only in v1: no comments, no reactions.
-- Those are v2, and no table for them exists here yet.

create table public.news_items (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  url          text not null,
  source       text,
  published_at timestamptz,
  summary      text,
  image_url    text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  -- The natural dedupe key across repeated feed polls.
  constraint news_items_url_key unique (url)
);

comment on table public.news_items is
  'Player news and injury updates from an external feed. A surrogate uuid PK
   with a unique url: the url is the real identity, but it is long and gets
   copied into the join table, so it is not used as the key itself.';

create trigger news_items_set_updated_at
  before update on public.news_items
  for each row execute function public.set_updated_at();

-- The player page query: newest news first.
create index news_items_published_at_idx
  on public.news_items (published_at desc nulls last);

-- ---------------------------------------------------------------------------
-- news_item_players
-- ---------------------------------------------------------------------------

create table public.news_item_players (
  news_item_id uuid not null references public.news_items (id) on delete cascade,
  player_id    text not null references public.players (player_id) on delete cascade,
  created_at   timestamptz not null default now(),

  primary key (news_item_id, player_id)
);

comment on table public.news_item_players is
  'Many-to-many: one story can mention several players. Unlike draft_picks,
   player_id IS a real FK here — the ingest function resolves players before
   writing the join row, so there is no sync-ordering hazard, and a news item
   pointing at a player who does not exist is never useful.';

-- The PK covers (news_item_id, player_id). This index serves the reverse
-- direction, which is the actual product query: news for a given player.
create index news_item_players_player_id_idx
  on public.news_item_players (player_id);

-- RLS ------------------------------------------------------------------------

alter table public.news_items enable row level security;
alter table public.news_item_players enable row level security;

create policy "News items are readable by authenticated users"
  on public.news_items for select to authenticated using (true);

create policy "News item players are readable by authenticated users"
  on public.news_item_players for select to authenticated using (true);
