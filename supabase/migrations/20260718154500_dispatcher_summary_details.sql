create or replace function public.get_dispatcher_summary_details(
  p_run_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_run public.dispatcher_summary_runs%rowtype;
  v_timezone text := 'Europe/Moscow';
  v_start timestamptz;
  v_week_end date;
  v_original_critical integer := 0;
  v_current_critical integer := 0;
  v_count integer := 0;
  v_items jsonb := '[]'::jsonb;
  v_deviations jsonb := '[]'::jsonb;
  v_context jsonb := '[]'::jsonb;
begin
  if auth.uid() is null or v_company_id is null then
    raise exception 'Требуется вход в компанию';
  end if;

  select * into v_run
  from public.dispatcher_summary_runs r
  where r.id = p_run_id
    and r.company_id = v_company_id;

  if not found then
    raise exception 'Сводка не найдена';
  end if;

  if public.normalize_notification_role(public.current_user_role()) = 'foreman'
     and not public.can_access_object(v_run.object_name) then
    raise exception 'Нет доступа к объекту этой сводки';
  end if;

  select coalesce(s.timezone, 'Europe/Moscow') into v_timezone
  from public.dispatcher_summary_settings s
  where s.company_id = v_run.company_id;

  v_timezone := coalesce(v_timezone, 'Europe/Moscow');
  v_start := v_run.summary_date::timestamp at time zone v_timezone;
  v_week_end := v_run.summary_date + 7;

  begin
    v_original_critical := coalesce(
      (v_run.payload ->> 'critical_count')::integer,
      0
    );
  exception when others then
    v_original_critical := 0;
  end;

  select count(*)::integer,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', p.id,
          'title', coalesce(nullif(btrim(e.fio), ''), 'Сотрудник'),
          'subtitle', format(
            '%s ₽ · %s',
            trim(to_char(p.amount, 'FM999999990D00')),
            to_char(p.payment_date, 'DD.MM.YYYY')
          ),
          'note', concat_ws(
            ' · ',
            nullif(btrim(coalesce(p.payment_type, '')), ''),
            nullif(btrim(coalesce(p.comment, '')), '')
          )
        )
        order by p.payment_date desc, e.fio, p.id
      ),
      '[]'::jsonb
    )
  into v_count, v_items
  from public.payments p
  join public.employees e
    on e.id = p.employee_id
   and e.company_id = p.company_id
  where p.company_id = v_run.company_id
    and lower(btrim(coalesce(e.object_name, ''))) =
        lower(btrim(v_run.object_name))
    and p.period_year = extract(year from v_run.summary_date)::integer
    and p.period_month = extract(month from v_run.summary_date)::integer
    and not exists (
      select 1
      from public.payment_receipts receipt
      where receipt.company_id = p.company_id
        and receipt.payment_id = p.id
    );

  if v_count > 0 then
    v_deviations := v_deviations || jsonb_build_array(
      jsonb_build_object(
        'key', 'payments_missing_receipts',
        'title', 'Выплаты без чеков',
        'count', v_count,
        'included_in_total', true,
        'items', v_items
      )
    );
    v_current_critical := v_current_critical + v_count;
  end if;

  select count(*)::integer,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', t.id,
          'title', coalesce(nullif(btrim(t.work), ''), 'Задача'),
          'subtitle', concat_ws(
            ' · ',
            nullif(btrim(coalesce(t.axes, '')), ''),
            nullif(btrim(coalesce(t.status, '')), '')
          ),
          'note', btrim(coalesce(t.not_done_comment, ''))
        )
        order by t.work, t.id
      ),
      '[]'::jsonb
    )
  into v_count, v_items
  from public.tasks t
  where t.company_id = v_run.company_id
    and lower(btrim(coalesce(t.object_name, ''))) =
        lower(btrim(v_run.object_name))
    and t.task_date = v_run.summary_date
    and not coalesce(t.is_draft, false)
    and btrim(coalesce(t.not_done_comment, '')) <> '';

  if v_count > 0 then
    v_deviations := v_deviations || jsonb_build_array(
      jsonb_build_object(
        'key', 'tasks_blocked',
        'title', 'Задачи с указанной проблемой',
        'count', v_count,
        'included_in_total', true,
        'items', v_items
      )
    );
    v_current_critical := v_current_critical + v_count;
  end if;

  select count(*)::integer,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', e.id,
          'title', coalesce(nullif(btrim(e.fio), ''), 'Сотрудник'),
          'subtitle', btrim(coalesce(e.position, '')),
          'note', format(
            'Нет отметки в табеле за %s',
            to_char(v_run.summary_date, 'DD.MM.YYYY')
          )
        )
        order by e.fio, e.id
      ),
      '[]'::jsonb
    )
  into v_count, v_items
  from public.employees e
  where e.company_id = v_run.company_id
    and lower(btrim(coalesce(e.object_name, ''))) =
        lower(btrim(v_run.object_name))
    and e.is_active = true
    and e.archived_at is null
    and not exists (
      select 1
      from public.attendance a
      where a.company_id = e.company_id
        and a.employee_id = e.id
        and a.work_date = v_run.summary_date
        and lower(btrim(coalesce(a.object_name, ''))) =
            lower(btrim(v_run.object_name))
    );

  if v_count > 0 then
    v_deviations := v_deviations || jsonb_build_array(
      jsonb_build_object(
        'key', 'attendance_missing',
        'title', 'Сотрудники без отметки в табеле',
        'count', v_count,
        'included_in_total', true,
        'items', v_items
      )
    );
    v_current_critical := v_current_critical + v_count;
  end if;

  select count(*)::integer,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', m.id,
          'title', coalesce(nullif(btrim(m.title), ''), 'Юридический вопрос'),
          'subtitle', concat_ws(
            ' · ',
            nullif(btrim(coalesce(m.status, '')), ''),
            case
              when m.due_at is not null
                then 'срок ' || to_char(m.due_at at time zone v_timezone, 'DD.MM.YYYY HH24:MI')
              else null
            end
          ),
          'note', btrim(coalesce(m.required_actions, m.description, ''))
        )
        order by m.due_at, m.title, m.id
      ),
      '[]'::jsonb
    )
  into v_count, v_items
  from public.legal_matters m
  where m.company_id = v_run.company_id
    and m.object_id = v_run.object_id
    and m.resolved_at is null
    and lower(coalesce(m.status, '')) not in (
      'закрыт', 'решён', 'resolved', 'closed'
    )
    and m.due_at < v_start;

  if v_count > 0 then
    v_deviations := v_deviations || jsonb_build_array(
      jsonb_build_object(
        'key', 'legal_overdue',
        'title', 'Просроченные юридические вопросы',
        'count', v_count,
        'included_in_total', true,
        'items', v_items
      )
    );
    v_current_critical := v_current_critical + v_count;
  end if;

  select count(*)::integer,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', m.id,
          'title', coalesce(nullif(btrim(m.title), ''), 'Юридический вопрос'),
          'subtitle', concat_ws(
            ' · ',
            nullif(btrim(coalesce(m.risk_level, '')), ''),
            nullif(btrim(coalesce(m.status, '')), '')
          ),
          'note', btrim(coalesce(m.required_actions, m.description, ''))
        )
        order by m.title, m.id
      ),
      '[]'::jsonb
    )
  into v_count, v_items
  from public.legal_matters m
  where m.company_id = v_run.company_id
    and m.object_id = v_run.object_id
    and m.resolved_at is null
    and lower(coalesce(m.status, '')) not in (
      'закрыт', 'решён', 'resolved', 'closed'
    )
    and lower(coalesce(m.risk_level, '')) in (
      'высокий', 'критический', 'high', 'critical'
    );

  if v_count > 0 then
    v_deviations := v_deviations || jsonb_build_array(
      jsonb_build_object(
        'key', 'legal_high_risk',
        'title', 'Юридические вопросы высокого риска',
        'count', v_count,
        'included_in_total', true,
        'items', v_items
      )
    );
    v_current_critical := v_current_critical + v_count;
  end if;

  select count(*)::integer,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', milestone.id,
          'title', coalesce(nullif(btrim(milestone.title), ''), 'Этап'),
          'subtitle', concat_ws(
            ' · ',
            nullif(btrim(coalesce(milestone.location, '')), ''),
            'срок ' || to_char(milestone.target_date, 'DD.MM.YYYY')
          ),
          'note', btrim(coalesce(milestone.notes, ''))
        )
        order by milestone.target_date, milestone.title, milestone.id
      ),
      '[]'::jsonb
    )
  into v_count, v_items
  from public.project_milestones milestone
  where milestone.company_id = v_run.company_id
    and lower(btrim(coalesce(milestone.object_name, ''))) =
        lower(btrim(v_run.object_name))
    and lower(coalesce(milestone.status, '')) not in (
      'выполнено', 'закрыто', 'completed', 'closed'
    )
    and milestone.target_date < v_run.summary_date;

  if v_count > 0 then
    v_deviations := v_deviations || jsonb_build_array(
      jsonb_build_object(
        'key', 'milestones_overdue',
        'title', 'Просроченные цели и этапы',
        'count', v_count,
        'included_in_total', true,
        'items', v_items
      )
    );
    v_current_critical := v_current_critical + v_count;
  end if;

  select count(*)::integer,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', t.id,
          'title', coalesce(nullif(btrim(t.work), ''), 'Задача'),
          'subtitle', concat_ws(
            ' · ',
            nullif(btrim(coalesce(t.axes, '')), ''),
            nullif(btrim(coalesce(t.status, '')), '')
          ),
          'note', btrim(coalesce(t.not_done_comment, ''))
        )
        order by t.work, t.id
      ),
      '[]'::jsonb
    )
  into v_count, v_items
  from public.tasks t
  where t.company_id = v_run.company_id
    and lower(btrim(coalesce(t.object_name, ''))) =
        lower(btrim(v_run.object_name))
    and t.task_date = v_run.summary_date
    and not coalesce(t.is_draft, false)
    and coalesce(t.status, '') <> 'Выполнено';

  if v_count > 0 then
    v_context := v_context || jsonb_build_array(
      jsonb_build_object(
        'key', 'tasks_pending',
        'title', 'Незакрытые задачи',
        'count', v_count,
        'included_in_total', false,
        'items', v_items
      )
    );
  end if;

  select count(*)::integer,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', document.id,
          'title', coalesce(nullif(btrim(document.title), ''), 'Документ'),
          'subtitle', concat_ws(
            ' · ',
            nullif(btrim(coalesce(document.document_type, '')), ''),
            'до ' || to_char(document.expires_on, 'DD.MM.YYYY')
          ),
          'note', btrim(coalesce(document.next_action, document.comment, ''))
        )
        order by document.expires_on, document.title, document.id
      ),
      '[]'::jsonb
    )
  into v_count, v_items
  from public.legal_documents document
  where document.company_id = v_run.company_id
    and document.object_id = v_run.object_id
    and document.archived_at is null
    and document.expires_on between v_run.summary_date and v_week_end;

  if v_count > 0 then
    v_context := v_context || jsonb_build_array(
      jsonb_build_object(
        'key', 'documents_expiring',
        'title', 'Документы с истекающим сроком',
        'count', v_count,
        'included_in_total', false,
        'items', v_items
      )
    );
  end if;

  return jsonb_build_object(
    'run_id', v_run.id,
    'object_id', v_run.object_id,
    'object_name', v_run.object_name,
    'summary_date', v_run.summary_date,
    'original_critical_count', v_original_critical,
    'current_critical_count', v_current_critical,
    'changed_since_summary', v_original_critical <> v_current_critical,
    'deviations', v_deviations,
    'context_groups', v_context
  );
end;
$$;

revoke all on function public.get_dispatcher_summary_details(uuid)
  from public, anon;
grant execute on function public.get_dispatcher_summary_details(uuid)
  to authenticated;

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
  v_body text;
  v_parts text[] := array[]::text[];
  v_value integer;
begin
  select * into v_run
  from public.dispatcher_summary_runs
  where id = p_run_id
    and dispatch_token = p_dispatch_token
  for update;

  if not found then
    raise exception 'Запуск не найден';
  end if;
  if v_run.status = 'sent' then
    return false;
  end if;
  if v_run.object_id is null or btrim(v_run.object_name) = '' then
    raise exception 'Для сводки не выбран объект';
  end if;

  select * into v_settings
  from public.dispatcher_summary_settings
  where company_id = v_run.company_id;
  if not found then
    raise exception 'Настройки диспетчера не найдены';
  end if;

  v_value := coalesce((p_payload #>> '{tasks,blocked}')::integer, 0);
  if v_value > 0 then
    v_parts := array_append(v_parts, format('задачи с проблемой — %s', v_value));
  end if;

  v_value := coalesce((p_payload #>> '{attendance,missing}')::integer, 0);
  if v_value > 0 then
    v_parts := array_append(v_parts, format('без отметки в табеле — %s', v_value));
  end if;

  v_value := coalesce((p_payload #>> '{payments,missing_receipts}')::integer, 0);
  if v_value > 0 then
    v_parts := array_append(v_parts, format('выплаты без чеков — %s', v_value));
  end if;

  v_value := coalesce((p_payload #>> '{legal,overdue}')::integer, 0);
  if v_value > 0 then
    v_parts := array_append(v_parts, format('юридические просрочки — %s', v_value));
  end if;

  v_value := coalesce((p_payload #>> '{legal,high_risk}')::integer, 0);
  if v_value > 0 then
    v_parts := array_append(v_parts, format('юридический высокий риск — %s', v_value));
  end if;

  v_value := coalesce((p_payload #>> '{milestones,overdue}')::integer, 0);
  if v_value > 0 then
    v_parts := array_append(v_parts, format('просроченные этапы — %s', v_value));
  end if;

  v_body := left(coalesce(p_body, ''), 7500);
  if coalesce(p_critical_count, 0) > 0
     and cardinality(v_parts) > 0 then
    v_body := left(
      v_body || E'\n\nРасшифровка отклонений: ' ||
      array_to_string(v_parts, ', ') || '.',
      8000
    );
  end if;

  foreach v_role in array v_settings.recipient_roles loop
    insert into public.app_notifications(
      company_id,
      title,
      body,
      actor_user_id,
      actor_name,
      actor_email,
      object_name,
      entity_type,
      entity_id,
      target_user_id,
      target_role,
      source_role,
      requires_action,
      due_at,
      priority,
      is_push_only,
      push_requested
    ) values (
      v_run.company_id,
      left(coalesce(p_title, ''), 240),
      v_body,
      null,
      'ИИ-диспетчер AppСтрой',
      '',
      v_run.object_name,
      'dispatcher_summary',
      v_run.id::text,
      null,
      v_role,
      'admin',
      coalesce(p_critical_count, 0) > 0,
      null,
      case
        when coalesce(p_critical_count, 0) > 0 then 'high'
        else 'normal'
      end,
      not v_settings.in_app_enabled,
      v_settings.push_enabled
    );
  end loop;

  update public.dispatcher_summary_runs
  set object_name = v_run.object_name,
      status = 'sent',
      title = left(coalesce(p_title, ''), 240),
      body = v_body,
      payload = coalesce(p_payload, '{}'::jsonb),
      ai_used = coalesce(p_ai_used, false),
      error_text = '',
      sent_at = now(),
      updated_at = now()
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
