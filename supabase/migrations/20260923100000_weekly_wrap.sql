-- Benchd v1 — the weekly wrap.
--
-- One week of a manager's football, across every league they play in, shaped for
-- the card that gets posted to Instagram. Computed on demand rather than cached:
-- unlike `career_stats` this reads a single week of `matchups`, which is a few
-- hundred rows behind an index, and a wrap that is a day stale is a wrap that
-- shows the wrong score.
--
-- Everything here is `security invoker`, so Row Level Security decides what the
-- caller can see. `my_rosters` reaches `sleeper_accounts`, whose policy is
-- owner-only, which is what stops one person reading another's week.

-- ---------------------------------------------------------------------------
-- my_rosters
-- ---------------------------------------------------------------------------

create view public.my_rosters
with (security_invoker = true)
as
with claimed as (
  select
    sa.id              as sleeper_account_id,
    sa.sleeper_user_id,
    lm.league_id,
    lm.roster_id,
    lm.team_name,
    (lm.sleeper_user_id = sa.sleeper_user_id) as is_owner
  from public.sleeper_accounts sa
  join public.league_members lm
    on lm.sleeper_user_id = sa.sleeper_user_id
    or sa.sleeper_user_id = any (coalesce(lm.co_owner_ids, array[]::text[]))
)
select
  c.sleeper_account_id,
  c.league_id,
  c.roster_id,
  c.team_name,
  l.name   as league_name,
  l.season as season
from claimed c
join public.leagues l on l.league_id = c.league_id
-- Ownership beats co-ownership: in a league where someone owns one team and
-- helps run another, only the team they own is theirs. A co-owned roster counts
-- only when they own nothing in that league — otherwise a co-manager would
-- inherit a second week's worth of results.
where c.is_owner
   or not exists (
     select 1
     from claimed other
     where other.sleeper_account_id = c.sleeper_account_id
       and other.league_id = c.league_id
       and other.is_owner
   );

comment on view public.my_rosters is
  'Every roster the calling user controls, one row per league-season. A
   security-invoker view, so sleeper_accounts'' owner-only policy scopes it to
   the caller with no WHERE clause of its own.';

-- ---------------------------------------------------------------------------
-- weekly_wrap
-- ---------------------------------------------------------------------------

create or replace function public.weekly_wrap(
  p_sleeper_account_id uuid,
  p_season integer,
  p_week integer
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
with mine as (
  select r.league_id, r.roster_id, r.team_name, r.league_name, l.total_rosters
  from public.my_rosters r
  join public.leagues l on l.league_id = r.league_id
  where r.sleeper_account_id = p_sleeper_account_id
    and r.season = p_season
),

-- The caller's own row in each league, for this week.
played as (
  select
    m.league_id,
    m.roster_id,
    m.league_name,
    coalesce(nullif(btrim(m.team_name), ''), 'Your team') as team_name,
    m.total_rosters,
    mu.matchup_id,
    coalesce(mu.custom_points, mu.points) as points,
    mu.starters,
    mu.players_points
  from mine m
  join public.matchups mu
    on mu.league_id = m.league_id
   and mu.roster_id = m.roster_id
   and mu.week = p_week
),

-- Every roster's score in those leagues, which is what makes "top score in the
-- league" and a weekly rank answerable.
league_week as (
  select
    mu.league_id,
    mu.roster_id,
    coalesce(mu.custom_points, mu.points) as points
  from public.matchups mu
  where mu.week = p_week
    and mu.league_id in (select league_id from mine)
),

standings as (
  select
    lw.league_id,
    lw.roster_id,
    rank() over (partition by lw.league_id order by lw.points desc nulls last) as league_rank,
    count(*) over (partition by lw.league_id) as teams
  from league_week lw
),

-- The other side of the head-to-head. Absent for a bye, and for the offseason
-- weeks Sleeper still answers for.
--
-- `distinct on` is load-bearing, not decoration: a matchup_id shared by more
-- than two rosters — a sync glitch, or a league Sleeper answered oddly for —
-- would otherwise return two opponents for one roster, and every row below
-- multiplies with it. The visible result is a wrap card claiming a 2–1 week
-- that was 1–1. One opponent per roster, always.
opponent as (
  select distinct on (p.league_id, p.roster_id)
    p.league_id,
    p.roster_id,
    coalesce(nullif(btrim(olm.team_name), ''), 'Unclaimed team') as opponent_name,
    coalesce(om.custom_points, om.points) as opponent_points
  from played p
  join public.matchups om
    on om.league_id = p.league_id
   and om.week = p_week
   and om.matchup_id = p.matchup_id
   and om.roster_id <> p.roster_id
  left join public.league_members olm
    on olm.league_id = om.league_id
   and olm.roster_id = om.roster_id
  where p.matchup_id is not null
  order by p.league_id, p.roster_id, om.roster_id
),

results as (
  select
    p.league_id,
    p.league_name,
    p.team_name,
    p.points,
    o.opponent_name,
    o.opponent_points,
    case
      when o.opponent_points is null then null
      when p.points > o.opponent_points then 'W'
      when p.points < o.opponent_points then 'L'
      else 'T'
    end as result,
    round(p.points - o.opponent_points, 2) as margin,
    s.league_rank,
    s.teams,
    -- Only claim the league's top score once every team has reported. Halfway
    -- through a sync — or halfway through a Sunday — two rosters have rows and
    -- the other ten do not, and "top score in the league" would be a boast the
    -- data does not support. This card gets posted in public; it does not get
    -- to be approximately true.
    (s.league_rank = 1 and s.teams >= coalesce(p.total_rosters, 4)) as league_high,
    (s.teams >= coalesce(p.total_rosters, 4)) as fully_reported
  from played p
  left join opponent o
    on o.league_id = p.league_id and o.roster_id = p.roster_id
  left join standings s
    on s.league_id = p.league_id and s.roster_id = p.roster_id
),

-- A week Sleeper has answered for but nobody has played yet comes back as a
-- full set of zeroes. That is not a wrap, and the function returns null for it.
scored as (
  select bool_or(coalesce(lw.points, 0) <> 0) as has_scoring from league_week lw
),

totals as (
  select
    count(*) filter (where r.result = 'W') as wins,
    count(*) filter (where r.result = 'L') as losses,
    count(*) filter (where r.result = 'T') as ties,
    count(*)                               as leagues,
    round(coalesce(sum(r.points), 0), 2)          as points_for,
    round(coalesce(sum(r.opponent_points), 0), 2) as points_against
  from results r
),

-- Starting lineups only: the bench is a different card.
starters as (
  select
    p.league_name,
    s.player_id,
    coalesce((p.players_points ->> s.player_id)::numeric, 0) as points
  from played p
  cross join lateral unnest(coalesce(p.starters, array[]::text[])) as s(player_id)
  -- Sleeper writes "0" into a starting slot that was left empty.
  where s.player_id is not null and s.player_id <> '0'
),

-- The same player can start in two leagues under different scoring settings and
-- score differently in each. His best day is the one worth posting.
best_per_player as (
  select distinct on (st.player_id)
    st.player_id, st.league_name, st.points
  from starters st
  order by st.player_id, st.points desc
),

performers as (
  select
    b.player_id,
    coalesce(nullif(btrim(pl.full_name), ''), 'Unknown player') as name,
    pl.position,
    pl.team,
    round(b.points, 2) as points,
    b.league_name
  from best_per_player b
  left join public.players pl on pl.player_id = b.player_id
  order by b.points desc, name
  limit 3
),

-- One thing worth saying out loud about the week, most postable first. A tie in
-- priority is broken by size, so the biggest version of a story wins.
highlight_candidates as (
  select 1 as priority, 'league_high' as kind,
         'Top score in the league' as headline,
         r.points as value, r.league_name as caption
  from results r
  where r.league_high and r.points is not null

  union all
  select 2, 'perfect_week',
         t.wins || '–0 on the week',
         t.wins::numeric, null
  from totals t
  where t.leagues > 1 and t.wins > 1 and t.losses = 0 and t.ties = 0

  union all
  select 3, 'close_win',
         'Won by ' || to_char(r.margin, 'FM999990.0'),
         r.margin, r.league_name
  from results r
  where r.result = 'W' and r.margin <= 3

  union all
  select 4, 'close_loss',
         'Lost by ' || to_char(abs(r.margin), 'FM999990.0'),
         abs(r.margin), r.league_name
  from results r
  where r.result = 'L' and abs(r.margin) <= 3

  union all
  select 5, 'big_win',
         'Won by ' || to_char(r.margin, 'FM999990.0'),
         r.margin, r.league_name
  from results r
  where r.result = 'W' and r.margin >= 30

  union all
  -- Always available once a week has been scored, so the card is never left
  -- without something to say.
  select 6, 'rank',
         to_char(r.league_rank, 'FM999th') || ' of ' || r.teams || ' this week',
         r.league_rank::numeric, r.league_name
  from results r
  where r.league_rank is not null and r.teams > 1 and r.fully_reported

  union all
  select 7, 'points',
         to_char(t.points_for, 'FM999990.0') || ' points',
         t.points_for, null
  from totals t
  where t.points_for > 0
),

highlight as (
  select h.kind, h.headline, h.value, h.caption
  from highlight_candidates h
  order by h.priority, h.value desc
  limit 1
)

select case
  when not (select s.has_scoring from scored s) then null
  when (select count(*) from played) = 0 then null
  else jsonb_build_object(
    'season', p_season,
    'week', p_week,
    'record', jsonb_build_object(
      'wins',   (select t.wins   from totals t),
      'losses', (select t.losses from totals t),
      'ties',   (select t.ties   from totals t)
    ),
    'points_for',     (select t.points_for     from totals t),
    'points_against', (select t.points_against from totals t),
    'leagues', coalesce(
      (select jsonb_agg(
         jsonb_build_object(
           'league_id',       r.league_id,
           'league_name',     r.league_name,
           'team_name',       r.team_name,
           'points',          round(r.points, 2),
           'opponent_name',   r.opponent_name,
           'opponent_points', round(r.opponent_points, 2),
           'result',          r.result,
           'margin',          r.margin,
           'league_rank',     r.league_rank,
           'teams',           r.teams,
           'league_high',     coalesce(r.league_high, false)
         )
         order by r.points desc nulls last
       ) from results r),
      '[]'::jsonb
    ),
    'performers', coalesce(
      (select jsonb_agg(
         jsonb_build_object(
           'player_id',   pf.player_id,
           'name',        pf.name,
           'position',    pf.position,
           'team',        pf.team,
           'points',      pf.points,
           'league_name', pf.league_name
         )
         order by pf.points desc, pf.name
       ) from performers pf),
      '[]'::jsonb
    ),
    'highlight', (
      select jsonb_build_object(
        'kind',     h.kind,
        'headline', h.headline,
        'value',    round(h.value, 2),
        'caption',  h.caption
      ) from highlight h
    )
  )
end;
$$;

comment on function public.weekly_wrap is
  'One week of one manager''s football, across every league they play in, as the
   weekly wrap card reads it. Returns null when the week has not been played.
   Security invoker: my_rosters is scoped to the caller by RLS.';

-- ---------------------------------------------------------------------------
-- recent_weekly_wraps
-- ---------------------------------------------------------------------------

create or replace function public.recent_weekly_wraps(
  p_sleeper_account_id uuid,
  p_limit integer default 8
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
with weeks as (
  select l.season, mu.week
  from public.my_rosters r
  join public.leagues l on l.league_id = r.league_id
  join public.matchups mu
    on mu.league_id = r.league_id
   and mu.roster_id = r.roster_id
  where r.sleeper_account_id = p_sleeper_account_id
  group by l.season, mu.week
  -- Weeks Sleeper answered for but nobody played come back as zeroes.
  having max(coalesce(mu.custom_points, mu.points, 0)) > 0
  order by l.season desc, mu.week desc
  limit greatest(coalesce(p_limit, 8), 1)
),
wraps as (
  select w.season, w.week, public.weekly_wrap(p_sleeper_account_id, w.season, w.week) as payload
  from weeks w
)
select coalesce(
  jsonb_agg(wr.payload order by wr.season desc, wr.week desc)
    filter (where wr.payload is not null),
  '[]'::jsonb
)
from wraps wr;
$$;

comment on function public.recent_weekly_wraps is
  'The most recently played weeks, newest first, each as a full weekly_wrap
   payload. The Wraps tab renders real cards as its history thumbnails, so the
   list has to carry whole wraps rather than a summary.';

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
--
-- Signed-in users only. `anon` is never granted anything here: the wrap reaches
-- sleeper_accounts, and an anonymous caller has no account to be scoped to.

revoke all on function public.weekly_wrap(uuid, integer, integer) from public;
revoke all on function public.recent_weekly_wraps(uuid, integer) from public;

grant execute on function public.weekly_wrap(uuid, integer, integer) to authenticated;
grant execute on function public.recent_weekly_wraps(uuid, integer) to authenticated;

-- The view inherits table-level RLS, but still needs the select privilege.
revoke all on public.my_rosters from public;
grant select on public.my_rosters to authenticated;

-- Indexes --------------------------------------------------------------------

-- `matchups` is already indexed on (league_id, week). The wrap's other hot path
-- is "every roster this Sleeper user owns", which league_members already covers
-- with its sleeper_user_id index. Co-ownership is the one lookup with no index:
-- it is an array containment test, and GIN is the only thing that can serve it.
create index league_members_co_owner_ids_idx
  on public.league_members using gin (co_owner_ids)
  where co_owner_ids is not null;
