-- Benchd v1 — scheduled syncs via pg_cron + pg_net.
--
-- Nothing secret is committed here. The function URL and the service key are
-- read from Supabase Vault at call time, by name. See the "Operator setup"
-- block at the bottom for the two commands that have to be run once, by hand,
-- against each environment.

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

-- A schema for machinery no client should ever reach.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Invoking an edge function
-- ---------------------------------------------------------------------------

create or replace function private.invoke_edge_function(
  function_name text,
  payload jsonb default '{}'::jsonb
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  base_url text;
  service_key text;
  request_id bigint;
begin
  select decrypted_secret into base_url
    from vault.decrypted_secrets where name = 'edge_function_base_url';

  select decrypted_secret into service_key
    from vault.decrypted_secrets where name = 'edge_function_service_key';

  if base_url is null or service_key is null then
    raise exception
      'Vault is missing edge_function_base_url or edge_function_service_key. See supabase/migrations/20260922100100_scheduled_sync.sql.';
  end if;

  select net.http_post(
    url := rtrim(base_url, '/') || '/' || function_name,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || service_key
    ),
    body := payload,
    -- Generous: a cold start plus a large league history is not quick. pg_net
    -- is fire-and-forget, so this only bounds how long the worker waits for a
    -- response it discards anyway.
    timeout_milliseconds := 120000
  ) into request_id;

  return request_id;
end;
$$;

comment on function private.invoke_edge_function is
  'Fire-and-forget POST to an edge function, authorised with the service key
   held in Vault. SECURITY DEFINER because only the owner may read Vault — and
   revoked from every client role below, since it would otherwise be a way to
   call any function with service-role rights.';

revoke all on function private.invoke_edge_function(text, jsonb)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Which accounts get refreshed
-- ---------------------------------------------------------------------------

create or replace function private.enqueue_active_account_syncs()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  account record;
  queued integer := 0;
begin
  for account in
    select sa.id
    from public.sleeper_accounts sa
    join public.profiles p on p.id = sa.profile_id
    where
      -- "Active" means the person opened the app recently, not that we synced
      -- recently — the latter would keep an abandoned account alive forever.
      p.last_seen_at > now() - interval '30 days'
      -- Never start a second run on top of a live one. A run still marked
      -- 'syncing' after an hour is treated as abandoned, since the edge
      -- function's own wall-clock budget is far shorter than that.
      and (
        sa.sync_status <> 'syncing'
        or sa.sync_started_at is null
        or sa.sync_started_at < now() - interval '1 hour'
      )
      -- Hourly cadence per account, with new accounts first.
      and (sa.last_synced_at is null or sa.last_synced_at < now() - interval '50 minutes')
    order by sa.last_synced_at asc nulls first
    -- A ceiling per tick. Sleeper allows ~1000 calls/minute and one account can
    -- be hundreds of calls, so the scheduler must not release an unbounded
    -- stampede in a single hour.
    limit 200
  loop
    perform private.invoke_edge_function(
      'sync-sleeper',
      jsonb_build_object('sleeper_account_id', account.id, 'trigger', 'cron')
    );
    queued := queued + 1;
  end loop;

  return queued;
end;
$$;

revoke all on function private.enqueue_active_account_syncs()
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Schedules
-- ---------------------------------------------------------------------------

-- Unschedule first so this migration can be re-run against an environment that
-- already has the jobs.
do $$
begin
  perform cron.unschedule('benchd-sync-players-daily');
exception when others then null;
end $$;

do $$
begin
  perform cron.unschedule('benchd-sync-sleeper-hourly');
exception when others then null;
end $$;

-- Players: once a day, which is what Sleeper asks for on this endpoint. 09:40
-- UTC is early morning US time — well clear of Sunday kickoff.
select cron.schedule(
  'benchd-sync-players-daily',
  '40 9 * * *',
  $cron$ select private.invoke_edge_function('sync-players'); $cron$
);

-- Accounts: hourly, at :20, so it never lines up with the players job.
select cron.schedule(
  'benchd-sync-sleeper-hourly',
  '20 * * * *',
  $cron$ select private.enqueue_active_account_syncs(); $cron$
);

-- ---------------------------------------------------------------------------
-- Operator setup — run once per environment, by hand. NOT part of this
-- migration, because neither value belongs in version control.
-- ---------------------------------------------------------------------------
--
--   select vault.create_secret(
--     'https://<project-ref>.supabase.co/functions/v1',
--     'edge_function_base_url',
--     'Base URL for Benchd edge functions'
--   );
--
--   select vault.create_secret(
--     '<service_role key from Project Settings -> API>',
--     'edge_function_service_key',
--     'Service role key used by pg_cron to authorise edge function calls'
--   );
--
-- To rotate a value later, use vault.update_secret(<id>, '<new value>').
--
-- Verify with:
--   select name from vault.decrypted_secrets;      -- names only
--   select jobname, schedule, active from cron.job;
--   select * from cron.job_run_details order by start_time desc limit 10;
