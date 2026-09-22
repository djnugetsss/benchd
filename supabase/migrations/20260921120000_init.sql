-- Benchd v1 — foundation: extensions, shared helpers, and profiles.
--
-- Scope note: this app is entirely free. There are no billing, subscription,
-- entitlement, or feature-gate tables anywhere in this schema, and none should
-- ever be added.

-- Trigram search for the player index (see the players migration).
-- Supabase convention keeps extensions out of the public schema.
create extension if not exists pg_trgm with schema extensions;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

-- Our own sync lifecycle, so an enum is safe — we control every value.
-- Values that come from Sleeper (league.status, draft.type) are stored as plain
-- text instead, because Sleeper can introduce a new value at any time and a
-- CHECK constraint would turn that into a failed sync rather than a new row.
create type public.sync_status as enum (
  'never_synced',
  'syncing',
  'synced',
  'failed'
);

-- ---------------------------------------------------------------------------
-- Shared helpers
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

comment on function public.set_updated_at is
  'Trigger helper: stamps updated_at on every UPDATE.';

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  avatar_url   text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.profiles is
  'One row per authenticated user. Private to its owner in v1 — there is no
   social graph until v2, so no cross-user read policy exists yet.';

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Create the profile row automatically on signup so an auth user can never
-- exist without one. SECURITY DEFINER is required to write into public.profiles
-- from the auth trigger context; search_path is pinned to empty and every
-- reference below is fully qualified.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    nullif(new.raw_user_meta_data ->> 'display_name', ''),
    nullif(new.raw_user_meta_data ->> 'avatar_url', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- RLS ------------------------------------------------------------------------

alter table public.profiles enable row level security;

-- auth.uid() is wrapped in a scalar subquery throughout this schema so Postgres
-- evaluates it once per statement (initplan) instead of once per row.
create policy "Profiles are viewable by their owner"
  on public.profiles for select to authenticated
  using (id = (select auth.uid()));

create policy "Profiles are insertable by their owner"
  on public.profiles for insert to authenticated
  with check (id = (select auth.uid()));

create policy "Profiles are updatable by their owner"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- No DELETE policy: a profile disappears when its auth.users row is deleted,
-- via the cascade above. Users should not be able to orphan their own account.
