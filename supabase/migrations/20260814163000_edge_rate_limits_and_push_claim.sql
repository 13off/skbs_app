create table if not exists private.edge_rate_limits (
  scope text not null,
  key_hash text not null,
  window_started_at timestamptz not null default now(),
  request_count integer not null default 1 check (request_count > 0),
  updated_at timestamptz not null default now(),
  primary key (scope, key_hash),
  check (char_length(scope) between 1 and 100),
  check (char_length(key_hash) between 32 and 128)
);

revoke all on table private.edge_rate_limits from public, anon, authenticated;

create index if not exists edge_rate_limits_updated_at_idx
  on private.edge_rate_limits(updated_at);

create or replace function public.consume_edge_rate_limit(
  p_scope text,
  p_key_hash text,
  p_limit integer,
  p_window_seconds integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_allowed boolean;
  v_now timestamptz := clock_timestamp();
begin
  if btrim(coalesce(p_scope, '')) = ''
     or btrim(coalesce(p_key_hash, '')) = ''
     or p_limit < 1
     or p_limit > 10000
     or p_window_seconds < 1
     or p_window_seconds > 604800 then
    raise exception 'Некорректные параметры ограничения частоты';
  end if;

  insert into private.edge_rate_limits(
    scope,
    key_hash,
    window_started_at,
    request_count,
    updated_at
  )
  values (btrim(p_scope), btrim(p_key_hash), v_now, 1, v_now)
  on conflict (scope, key_hash) do update
  set window_started_at = case
        when private.edge_rate_limits.window_started_at <=
             v_now - make_interval(secs => p_window_seconds)
          then v_now
        else private.edge_rate_limits.window_started_at
      end,
      request_count = case
        when private.edge_rate_limits.window_started_at <=
             v_now - make_interval(secs => p_window_seconds)
          then 1
        else private.edge_rate_limits.request_count + 1
      end,
      updated_at = v_now
  where private.edge_rate_limits.window_started_at <=
          v_now - make_interval(secs => p_window_seconds)
     or private.edge_rate_limits.request_count < p_limit
  returning true into v_allowed;

  -- Amortized cleanup keeps one-off IP/phone hashes from growing forever.
  -- The longest permitted window is seven days, so eight-day-old rows are safe.
  if random() < 0.01 then
    delete from private.edge_rate_limits limits
    where limits.ctid in (
      select stale.ctid
      from private.edge_rate_limits stale
      where stale.updated_at < v_now - interval '8 days'
      order by stale.updated_at
      limit 1000
    );
  end if;

  return coalesce(v_allowed, false);
end;
$$;

revoke all on function public.consume_edge_rate_limit(text,text,integer,integer)
  from public, anon, authenticated;
grant execute on function public.consume_edge_rate_limit(text,text,integer,integer)
  to service_role;

alter table public.push_notification_jobs
  add column if not exists lease_token uuid;

create or replace function public.claim_push_notification_job(
  p_job_id uuid,
  p_dispatch_token uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job public.push_notification_jobs%rowtype;
  v_lease_token uuid;
begin
  select * into v_job
  from public.push_notification_jobs job
  where job.id = p_job_id
    and job.dispatch_token = p_dispatch_token
  for update;

  if not found then raise exception 'Задание push не найдено'; end if;
  if v_job.status in ('sent', 'partial', 'no_recipients') then
    return jsonb_build_object(
      'claimed', false,
      'status', v_job.status,
      'id', v_job.id,
      'notification_id', v_job.notification_id
    );
  end if;
  if v_job.status = 'processing'
     and v_job.updated_at > clock_timestamp() - interval '15 minutes' then
    return jsonb_build_object(
      'claimed', false,
      'status', 'processing',
      'id', v_job.id,
      'notification_id', v_job.notification_id
    );
  end if;

  v_lease_token := gen_random_uuid();
  update public.push_notification_jobs job
  set status = 'processing',
      attempts = job.attempts + 1,
      last_error = '',
      lease_token = v_lease_token,
      updated_at = clock_timestamp()
  where job.id = v_job.id
  returning * into v_job;

  return jsonb_build_object(
    'claimed', true,
    'status', v_job.status,
    'id', v_job.id,
    'notification_id', v_job.notification_id,
    'dispatch_token', v_job.dispatch_token,
    'lease_token', v_job.lease_token,
    'attempts', v_job.attempts,
    'updated_at', v_job.updated_at
  );
end;
$$;

revoke all on function public.claim_push_notification_job(uuid,uuid)
  from public, anon, authenticated;
grant execute on function public.claim_push_notification_job(uuid,uuid)
  to service_role;

comment on function public.consume_edge_rate_limit(text,text,integer,integer) is
  'Атомарный fixed-window rate limit для публичных Edge Functions; доступен только service_role.';
comment on function public.claim_push_notification_job(uuid,uuid) is
  'Атомарно захватывает push-задание и выдаёт lease token одному обработчику.';
