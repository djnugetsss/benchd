-- Benchd v1 — store the raw winners bracket on the league.
--
-- `league_members.finish_rank` already records where a roster finished, which is
-- enough to count championships. It is not enough for a playoff record.
--
-- Playoff-week rows in `matchups` are not the playoffs: Sleeper puts the
-- consolation bracket in the same weeks. Counting weeks would credit a team that
-- missed the playoffs with a "playoff run", and charge a team eliminated in
-- round one with losses in games that decided nothing. The winners bracket is
-- the only place the real answer lives, and it is small — a dozen entries per
-- league — so it is kept verbatim rather than flattened into columns, matching
-- how `settings` and `scoring_settings` are stored.

alter table public.leagues
  add column winners_bracket jsonb;

comment on column public.leagues.winners_bracket is
  'Sleeper /league/{id}/winners_bracket, verbatim. An array of
   { r, m, t1, t2, w, l, p }: r is the round, t1/t2 the two rosters (or
   { "w": 3 } placeholders before the feeder game is decided), w/l the winning
   and losing roster_id, and p the placement the game settles — p = 1 is the
   championship. Null until the league has been synced since this column
   landed, and empty for leagues whose playoffs have not been seeded; the career
   computation falls back to finish_rank in both cases.';
