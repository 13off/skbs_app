-- Автоматические «Дела» руководителя по фактам из ежедневных отчётов.
-- Генерация использует те же private.manager_report_* функции, что и экран
-- отчётов, поэтому UI и автоматизация не расходятся по смыслу.

create or replace function private.sync_manager_report_todo_issue(
  p_company_id uuid,
  p_report_date date,
  p_due_at timestamptz,
  p_issue_code text,
  p_title text,
  p_body text,
  p_count integer,
  p_priority text default 'normal',
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_existing_id uuid;
  v_source_key text;
  v_metadata jsonb;
begin
  if p_company_id is null
    or p_report_date is null
    or nullif(btrim(coalesce(p_issue_code, '')), '') is null
  then
    return;
  end if;

  v_metadata := coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object(
    'issue_code', p_issue_code,
    'report_date', p_report_date,
    'count', greatest(coalesce(p_count, 0), 0),
    'source', 'manager_reports_center',
    'scope', 'company'
  );

  -- Для каждого типа проблемы держим только одно открытое дело. Если проблема
  -- живёт несколько дней, обновляем его и переносим утреннее напоминание,
  -- вместо создания дублей.
  select todo.id
    into v_existing_id
  from public.manager_todos todo
  where todo.company_id = p_company_id
    and todo.source_type = 'manager_report'
    and todo.status = 'open'
    and todo.metadata ->> 'issue_code' = p_issue_code
  order by todo.created_at desc
  limit 1
  for update;

  if greatest(coalesce(p_count, 0), 0) = 0 then
    if v_existing_id is not null then
      update public.manager_todos
      set status = 'done',
          completed_by = null,
          completed_at = now(),
          metadata = metadata || jsonb_build_object(
            'auto_resolved', true,
            'resolved_at', now(),
            'last_report_date', p_report_date
          ),
          updated_at = now()
      where id = v_existing_id;
    end if;
    return;
  end if;

  if v_existing_id is not null then
    update public.manager_todos
    set title = left(btrim(coalesce(p_title, '')), 300),
        body = left(btrim(coalesce(p_body, '')), 4000),
        source_date = p_report_date,
        due_at = p_due_at,
        reminder_at = p_due_at,
        priority = case
          when p_priority in ('low', 'normal', 'high', 'critical') then p_priority
          else 'normal'
        end,
        metadata = v_metadata || jsonb_build_object('auto_resolved', false),
        updated_at = now()
    where id = v_existing_id;
    return;
  end if;

  v_source_key := 'report:' || p_issue_code || ':' || p_report_date::text;

  insert into public.manager_todos(
    company_id,
    title,
    body,
    status,
    due_at,
    reminder_at,
    priority,
    source_type,
    source_key,
    source_date,
    metadata,
    recipient_user_id,
    target_role,
    created_by
  ) values (
    p_company_id,
    left(btrim(coalesce(p_title, '')), 300),
    left(btrim(coalesce(p_body, '')), 4000),
    'open',
    p_due_at,
    p_due_at,
    case
      when p_priority in ('low', 'normal', 'high', 'critical') then p_priority
      else 'normal'
    end,
    'manager_report',
    v_source_key,
    p_report_date,
    v_metadata || jsonb_build_object('auto_resolved', false),
    null,
    'admin',
    null
  )
  on conflict (company_id, source_type, source_key)
    where source_key is not null
  do nothing;
end;
$$;

create or replace function private.populate_manager_report_todos()
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_today date := (now() at time zone 'Europe/Moscow')::date;
  v_report_date date := (now() at time zone 'Europe/Moscow')::date - 1;
  v_now_local timestamp := now() at time zone 'Europe/Moscow';
  v_due_at timestamptz := (
    (now() at time zone 'Europe/Moscow')::date + time '08:00'
  ) at time zone 'Europe/Moscow';
  v_company record;
  v_tasks jsonb;
  v_people jsonb;
  v_finance jsonb;
  v_legal jsonb;
  v_milestones jsonb;
  v_attendance_missing integer;
  v_tasks_pending integer;
  v_tasks_problem integer;
  v_missing_receipts integer;
  v_legal_overdue integer;
  v_legal_high_risk integer;
  v_expiring_documents integer;
  v_milestones_overdue integer;
begin
  -- В 07:55 МСК задачи уже готовы, а существующий обработчик scheduled_reminders
  -- отправит push/in-app напоминание в 08:00. После 08:00 функция продолжает
  -- синхронизировать факты: исчезнувшая проблема уходит в «Выполненные».
  if v_now_local < v_today + time '07:55' then
    return;
  end if;

  for v_company in
    select company.id
    from public.companies company
    where company.status = 'active'
  loop
    v_tasks := private.manager_report_tasks_v2(
      v_company.id,
      null,
      v_report_date
    );
    v_people := private.manager_report_people_v2(
      v_company.id,
      null,
      v_report_date
    );
    v_finance := private.manager_report_finance_v2(
      v_company.id,
      null,
      v_report_date
    );
    v_legal := private.manager_report_legal(
      v_company.id,
      null,
      v_report_date
    );
    v_milestones := private.manager_report_milestones_v2(
      v_company.id,
      null,
      v_report_date
    );

    v_attendance_missing := coalesce(
      (v_people #>> '{attendance,missing}')::integer,
      0
    );
    v_tasks_pending := coalesce(
      (v_tasks #>> '{metrics,pending}')::integer,
      0
    );
    v_tasks_problem := coalesce(
      (v_tasks #>> '{metrics,problem}')::integer,
      0
    );
    v_missing_receipts := coalesce(
      (v_finance #>> '{metrics,missing_receipts_month}')::integer,
      0
    );
    v_legal_overdue := coalesce(
      (v_legal #>> '{metrics,overdue}')::integer,
      0
    );
    v_legal_high_risk := coalesce(
      (v_legal #>> '{metrics,high_risk}')::integer,
      0
    );
    v_expiring_documents := coalesce(
      (v_legal #>> '{metrics,expiring_documents}')::integer,
      0
    );
    v_milestones_overdue := coalesce(
      (v_milestones #>> '{metrics,overdue}')::integer,
      0
    );

    perform private.sync_manager_report_todo_issue(
      v_company.id,
      v_report_date,
      v_due_at,
      'attendance_missing',
      'Закрыть пропуски в табеле',
      format(
        'За %s нет отметки у %s сотрудников. Проверь и закрой табель до расчёта смен.',
        to_char(v_report_date, 'DD.MM.YYYY'),
        v_attendance_missing
      ),
      v_attendance_missing,
      'high',
      jsonb_build_object(
        'missing_count', v_attendance_missing,
        'items', coalesce(v_people -> 'missing_items', '[]'::jsonb)
      )
    );

    perform private.sync_manager_report_todo_issue(
      v_company.id,
      v_report_date,
      v_due_at,
      'tasks_pending',
      'Проверить незавершённые работы',
      format(
        'За %s незакрыто %s задач, из них с проблемой — %s. Уточни результат, сроки и ответственных.',
        to_char(v_report_date, 'DD.MM.YYYY'),
        v_tasks_pending,
        v_tasks_problem
      ),
      v_tasks_pending,
      case when v_tasks_problem > 0 then 'high' else 'normal' end,
      jsonb_build_object(
        'pending_count', v_tasks_pending,
        'problem_count', v_tasks_problem,
        'items', coalesce(v_tasks -> 'pending_items', '[]'::jsonb)
      )
    );

    perform private.sync_manager_report_todo_issue(
      v_company.id,
      v_report_date,
      v_due_at,
      'payment_receipts_missing',
      'Собрать подтверждающие чеки',
      format(
        'В реестре выплат не хватает %s подтверждающих чеков. Собери и прикрепи их к выплатам.',
        v_missing_receipts
      ),
      v_missing_receipts,
      'high',
      jsonb_build_object(
        'missing_receipts', v_missing_receipts,
        'items', coalesce(v_finance -> 'missing_items', '[]'::jsonb)
      )
    );

    perform private.sync_manager_report_todo_issue(
      v_company.id,
      v_report_date,
      v_due_at,
      'legal_risks',
      'Проверить юридические риски',
      format(
        'Юридические вопросы требуют внимания: просрочено — %s, высокого риска — %s.',
        v_legal_overdue,
        v_legal_high_risk
      ),
      v_legal_overdue + v_legal_high_risk,
      'high',
      jsonb_build_object(
        'overdue_count', v_legal_overdue,
        'high_risk_count', v_legal_high_risk,
        'items', coalesce(v_legal -> 'attention_items', '[]'::jsonb)
      )
    );

    perform private.sync_manager_report_todo_issue(
      v_company.id,
      v_report_date,
      v_due_at,
      'legal_documents_expiring',
      'Проверить истекающие документы',
      format(
        'Срок действия подходит к концу у %s документов. Проверь продление или замену.',
        v_expiring_documents
      ),
      v_expiring_documents,
      'normal',
      jsonb_build_object(
        'expiring_documents', v_expiring_documents,
        'items', coalesce(v_legal -> 'attention_items', '[]'::jsonb)
      )
    );

    perform private.sync_manager_report_todo_issue(
      v_company.id,
      v_report_date,
      v_due_at,
      'milestones_overdue',
      'Сверить просроченные этапы',
      format(
        'По объектам просрочено %s этапов. Сверь фактический прогресс, сроки и ответственных.',
        v_milestones_overdue
      ),
      v_milestones_overdue,
      'high',
      jsonb_build_object(
        'overdue_count', v_milestones_overdue,
        'items', coalesce(v_milestones -> 'attention_items', '[]'::jsonb)
      )
    );
  end loop;
end;
$$;

create or replace function private.populate_role_operational_reminders()
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
begin
  perform private.populate_foreman_configured_reminders();
  perform private.populate_backoffice_configured_reminders();
  perform private.populate_developer_custom_reminders();
  perform private.populate_manager_absence_todos();
  perform private.populate_manager_report_todos();
end;
$$;

revoke all on function private.sync_manager_report_todo_issue(
  uuid, date, timestamptz, text, text, text, integer, text, jsonb
) from public, anon, authenticated;
revoke all on function private.populate_manager_report_todos()
  from public, anon, authenticated;
