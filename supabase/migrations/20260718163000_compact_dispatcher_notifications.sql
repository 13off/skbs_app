create or replace function public.finalize_dispatcher_object_summary(
  p_run_id uuid,
  p_dispatch_token uuid,
  p_title text,
  p_body text,
  p_payload jsonb,
  p_ai_used boolean,
  p_critical_count integer
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_run public.dispatcher_summary_runs%rowtype;
  v_settings public.dispatcher_summary_settings%rowtype;
  v_role text;
  v_full_body text;
  v_notification_body text;
  v_parts text[] := array[]::text[];
  v_value integer;
begin
  select * into v_run
  from public.dispatcher_summary_runs
  where id = p_run_id and dispatch_token = p_dispatch_token
  for update;

  if not found then raise exception 'Запуск не найден'; end if;
  if v_run.status = 'sent' then return false; end if;
  if v_run.object_id is null or btrim(v_run.object_name) = '' then
    raise exception 'Для сводки не выбран объект';
  end if;

  select * into v_settings
  from public.dispatcher_summary_settings
  where company_id = v_run.company_id;
  if not found then raise exception 'Настройки диспетчера не найдены'; end if;

  v_value := coalesce((p_payload #>> '{tasks,blocked}')::integer, 0);
  if v_value > 0 then v_parts := array_append(v_parts, format('задачи с проблемой — %s', v_value)); end if;
  v_value := coalesce((p_payload #>> '{attendance,missing}')::integer, 0);
  if v_value > 0 then v_parts := array_append(v_parts, format('без табеля — %s', v_value)); end if;
  v_value := coalesce((p_payload #>> '{payments,missing_receipts}')::integer, 0);
  if v_value > 0 then v_parts := array_append(v_parts, format('без чеков — %s', v_value)); end if;
  v_value := coalesce((p_payload #>> '{legal,overdue}')::integer, 0);
  if v_value > 0 then v_parts := array_append(v_parts, format('юридические просрочки — %s', v_value)); end if;
  v_value := coalesce((p_payload #>> '{legal,high_risk}')::integer, 0);
  if v_value > 0 then v_parts := array_append(v_parts, format('высокий юр. риск — %s', v_value)); end if;
  v_value := coalesce((p_payload #>> '{milestones,overdue}')::integer, 0);
  if v_value > 0 then v_parts := array_append(v_parts, format('просроченные этапы — %s', v_value)); end if;

  v_full_body := left(coalesce(p_body, ''), 8000);
  if coalesce(p_critical_count, 0) > 0 then
    v_notification_body := format('Отклонений: %s', p_critical_count);
    if cardinality(v_parts) > 0 then
      v_notification_body := v_notification_body || ' · ' || array_to_string(v_parts, ', ');
    end if;
    v_notification_body := left(v_notification_body || '. Открой отчёт.', 700);
  else
    v_notification_body := 'Сводка готова. Критичных отклонений нет. Открой отчёт.';
  end if;

  foreach v_role in array v_settings.recipient_roles loop
    insert into public.app_notifications(
      company_id, title, body, actor_user_id, actor_name, actor_email,
      object_name, entity_type, entity_id, target_user_id, target_role,
      source_role, requires_action, due_at, priority, is_push_only,
      push_requested
    ) values (
      v_run.company_id, left(coalesce(p_title, ''), 240), v_notification_body,
      null, 'ИИ-диспетчер AppСтрой', '', v_run.object_name,
      'dispatcher_summary', v_run.id::text, null, v_role, 'admin',
      coalesce(p_critical_count, 0) > 0, null,
      case when coalesce(p_critical_count, 0) > 0 then 'high' else 'normal' end,
      not v_settings.in_app_enabled, v_settings.push_enabled
    );
  end loop;

  update public.dispatcher_summary_runs
  set object_name = v_run.object_name,
      status = 'sent',
      title = left(coalesce(p_title, ''), 240),
      body = v_full_body,
      payload = coalesce(p_payload, '{}'::jsonb),
      ai_used = coalesce(p_ai_used, false),
      error_text = '', sent_at = now(), updated_at = now()
  where id = v_run.id;

  return true;
end;
$$;

revoke all on function public.finalize_dispatcher_object_summary(
  uuid, uuid, text, text, jsonb, boolean, integer
) from public, anon, authenticated;
grant execute on function public.finalize_dispatcher_object_summary(
  uuid, uuid, text, text, jsonb, boolean, integer
) to service_role;

update public.app_notifications n
set body = case
  when coalesce((r.payload ->> 'critical_count')::integer, 0) > 0 then
    left(
      format(
        'Отклонений: %s%s. Открой отчёт.',
        coalesce((r.payload ->> 'critical_count')::integer, 0),
        case
          when coalesce((r.payload #>> '{payments,missing_receipts}')::integer, 0) > 0
            then format(' · без чеков — %s', (r.payload #>> '{payments,missing_receipts}')::integer)
          else ''
        end
      ),
      700
    )
  else 'Сводка готова. Критичных отклонений нет. Открой отчёт.'
end
from public.dispatcher_summary_runs r
where n.entity_type = 'dispatcher_summary'
  and n.entity_id = r.id::text;
