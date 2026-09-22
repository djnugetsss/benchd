-- Benchd v1 — connected Sleeper accounts.

create table public.sleeper_accounts (
  id               uuid primary key default gen_random_uuid(),
  profile_id       uuid not null references public.profiles (id) on delete cascade,
  sleeper_user_id  text not null,
  username         text,
  display_name     text,
  avatar           text,
  last_synced_at   timestamptz,
  sync_status      public.sync_status not null default 'never_synced',
  sync_error       text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),

  -- The same Sleeper account cannot be connected twice by one profile.
  constraint sleeper_accounts_profile_user_key unique (profile_id, sleeper_user_id)
);

comment on table public.sleeper_accounts is
  'A Sleeper account connected to a Benchd profile. Deliberately NOT unique on
   sleeper_user_id alone: two people can legitimately connect the same public
   Sleeper account, and Sleeper data is read-only and public anyway.';

comment on column public.sleeper_accounts.avatar is
  'Sleeper avatar id, not a URL. Resolve client-side against
   https://sleepercdn.com/avatars/<avatar>.';

comment on column public.sleeper_accounts.sync_error is
  'Last failure message when sync_status = failed. Cleared on success.';

create trigger sleeper_accounts_set_updated_at
  before update on public.sleeper_accounts
  for each row execute function public.set_updated_at();

-- Indexes --------------------------------------------------------------------

-- Postgres does not index foreign keys automatically.
create index sleeper_accounts_profile_id_idx
  on public.sleeper_accounts (profile_id);

-- The sync worker claims accounts by staleness.
create index sleeper_accounts_sync_idx
  on public.sleeper_accounts (sync_status, last_synced_at nulls first);

-- Joining league_members back to a connected account.
create index sleeper_accounts_sleeper_user_id_idx
  on public.sleeper_accounts (sleeper_user_id);

-- RLS ------------------------------------------------------------------------

alter table public.sleeper_accounts enable row level security;

create policy "Sleeper accounts are viewable by their owner"
  on public.sleeper_accounts for select to authenticated
  using (profile_id = (select auth.uid()));

create policy "Sleeper accounts are insertable by their owner"
  on public.sleeper_accounts for insert to authenticated
  with check (profile_id = (select auth.uid()));

create policy "Sleeper accounts are updatable by their owner"
  on public.sleeper_accounts for update to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

-- Disconnecting an account is a normal user action.
create policy "Sleeper accounts are deletable by their owner"
  on public.sleeper_accounts for delete to authenticated
  using (profile_id = (select auth.uid()));
