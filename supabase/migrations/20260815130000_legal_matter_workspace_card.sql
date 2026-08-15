-- Полноценная карточка юридического дела: отдельное основание и append-only история.

alter table public.legal_matters
  add column if not exists basis text not null default '';

create table if not exists public.legal_matter_events (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null default public.current_user_company_id(),
  matter_id uuid not null references public.legal_matters(id) on delete cascade,
  event_type text not null default 'note',
  title text not null default '',
  body text not null default '',
  actor_user_id uuid null references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint legal_matter_events_type_check check (
    event_type in ('created', 'updated', 'status', 'decision', 'note')
  )
);

create index if not exists legal_matter_events_matter_created_idx
  on public.legal_matter_events (matter_id, created_at desc);
create index if not exists legal_matter_events_company_idx
  on public.legal_matter_events (company_id);

alter table public.legal_matter_events enable row level security;

revoke all on table public.legal_matter_events from public, anon;
revoke all on table public.legal_matter_events from authenticated;
grant select, insert on table public.legal_matter_events to authenticated;

DROP POLICY IF EXISTS legal_matter_events_select ON public.legal_matter_events;
CREATE POLICY legal_matter_events_select
ON public.legal_matter_events
FOR SELECT
TO authenticated
USING (
  company_id = (select public.current_user_company_id())
  AND public.legal_matter_allowed_for_user(matter_id)
);

DROP POLICY IF EXISTS legal_matter_events_insert ON public.legal_matter_events;
CREATE POLICY legal_matter_events_insert
ON public.legal_matter_events
FOR INSERT
TO authenticated
WITH CHECK (
  company_id = (select public.current_user_company_id())
  AND actor_user_id = auth.uid()
  AND public.current_user_has_permission('legal.matters.edit')
  AND public.legal_matter_allowed_for_user(matter_id)
);

create or replace function public.log_legal_matter_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid;
  v_type text;
  v_title text;
  v_body text;
begin
  v_actor := coalesce(auth.uid(), new.updated_by, new.created_by);

  if tg_op = 'INSERT' then
    v_type := 'created';
    v_title := 'Дело создано';
    v_body := 'Статус: ' || coalesce(new.status, 'open') || '. Риск: ' || coalesce(new.risk_level, 'medium') || '.';
  elsif old.status is distinct from new.status then
    v_type := 'status';
    v_title := 'Изменён статус';
    v_body := coalesce(old.status, '—') || ' → ' || coalesce(new.status, '—');
  elsif old.decision_status is distinct from new.decision_status then
    v_type := 'decision';
    v_title := 'Решение руководителя';
    v_body := case
      when coalesce(new.decision_comment, '') <> ''
        then coalesce(new.decision_status, '—') || ': ' || new.decision_comment
      else coalesce(new.decision_status, '—')
    end;
  else
    v_type := 'updated';
    v_title := 'Карточка обновлена';
    v_body := '';
  end if;

  insert into public.legal_matter_events (
    company_id,
    matter_id,
    event_type,
    title,
    body,
    actor_user_id
  ) values (
    new.company_id,
    new.id,
    v_type,
    v_title,
    v_body,
    v_actor
  );

  return new;
end;
$$;

DROP TRIGGER IF EXISTS legal_matters_history_trigger ON public.legal_matters;
CREATE TRIGGER legal_matters_history_trigger
AFTER INSERT OR UPDATE ON public.legal_matters
FOR EACH ROW
EXECUTE FUNCTION public.log_legal_matter_change();

-- Существующие дела получают стартовую запись, чтобы история не выглядела пустой.
insert into public.legal_matter_events (
  company_id,
  matter_id,
  event_type,
  title,
  body,
  actor_user_id,
  created_at
)
select
  m.company_id,
  m.id,
  'created',
  'Дело создано',
  'Статус: ' || coalesce(m.status, 'open') || '. Риск: ' || coalesce(m.risk_level, 'medium') || '.',
  m.created_by,
  m.created_at
from public.legal_matters m
where not exists (
  select 1
  from public.legal_matter_events e
  where e.matter_id = m.id
);
