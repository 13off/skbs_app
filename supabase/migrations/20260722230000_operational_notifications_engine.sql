create unique index if not exists app_notifications_operational_dedupe_idx
on public.app_notifications(
  company_id,
  entity_type,
  entity_id,
  coalesce(target_role, ''),
  coalesce(target_user_id, '00000000-0000-0000-0000-000000000000'::uuid)
)
where entity_type like 'operational_%' or entity_type = 'ai_draft';

create or replace function private.insert_operational_notification(
  p_company_id uuid,
  p_title text,
  p_body text,
  p_object_name text,
  p_entity_type text,
  p_entity_id text,
  p_target_role text,
  p_priority text,
  p_source_role text,
  p_due_at timestamptz default null,
  p_target_user_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
begin
  insert into public.app_notifications(
    company_id, title, body, actor_user_id, actor_name, actor_email,
    object_name, entity_type, entity_id, target_user_id, target_role,
    requires_action, due_at, priority, source_role, is_push_only,
    push_requested
  ) values (
    p_company_id,
    left(p_title, 220),
    left(p_body, 1200),
    null,
    'Система AppСтрой',
    '',
    coalesce(p_object_name, ''),
    p_entity_type,
    p_entity_id,
    p_target_user_id,
    p_target_role,
    true,
    p_due_at,
    p_priority,
    p_source_role,
    false,
    true
  )
  on conflict do nothing;
end;
$$;

create or replace function private.refresh_operational_notifications_for_company(
  p_company_id uuid,
  p_date date default (timezone('Europe/Moscow', now()))::date
)
returns integer
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  item record;
  v_inserted integer := 0;
  v_month_start date := date_trunc('month', p_date)::date;
  v_month_end date := (date_trunc('month', p_date) + interval '1 month - 1 day')::date;
  v_hour integer := extract(hour from timezone('Europe/Moscow', now()));
begin
  if not exists (
    select 1 from public.companies company
    where company.id = p_company_id and company.status = 'active'
  ) then
    return 0;
  end if;

  for item in
    select task_row.object_id, task_row.object_name, count(*)::integer as item_count
    from public.tasks task_row
    where task_row.company_id = p_company_id
      and task_row.deleted_at is null
      and not task_row.is_draft
      and task_row.task_date < p_date
      and task_row.status <> 'Выполнено'
    group by task_row.object_id, task_row.object_name
  loop
    perform private.insert_operational_notification(
      p_company_id,
      'Просроченные задачи',
      format('На объекте «%s» просрочено задач: %s. Проверь статусы и причины невыполнения.', item.object_name, item.item_count),
      item.object_name,
      'operational_overdue_tasks',
      format('%s:%s:%s', p_date, coalesce(item.object_id::text, item.object_name), 'overdue'),
      'foreman', 'high', 'foreman', now(), null
    );
    v_inserted := v_inserted + 1;
  end loop;

  for item in
    select task_row.object_id, task_row.object_name, count(*)::integer as item_count
    from public.tasks task_row
    where task_row.company_id = p_company_id
      and task_row.deleted_at is null
      and not task_row.is_draft
      and task_row.photo_requirements_enforced
      and task_row.task_date <= p_date
      and (
        (
          coalesce((public.get_effective_task_policy(task_row.object_name)->>'require_before_photo')::boolean, false)
          and (
            select count(*) from public.task_photos photo
            where photo.task_id = task_row.id and photo.photo_stage = 'before'
          ) < coalesce((public.get_effective_task_policy(task_row.object_name)->>'min_before_photos')::integer, 1)
        )
        or (
          task_row.status = 'Выполнено'
          and coalesce((public.get_effective_task_policy(task_row.object_name)->>'require_after_photo_on_complete')::boolean, false)
          and (
            select count(*) from public.task_photos photo
            where photo.task_id = task_row.id and photo.photo_stage = 'after'
          ) < coalesce((public.get_effective_task_policy(task_row.object_name)->>'min_after_photos')::integer, 1)
        )
      )
    group by task_row.object_id, task_row.object_name
  loop
    perform private.insert_operational_notification(
      p_company_id,
      'Не хватает фотографий по задачам',
      format('На объекте «%s» задач с незакрытыми требованиями по фото: %s.', item.object_name, item.item_count),
      item.object_name,
      'operational_missing_photos',
      format('%s:%s:%s', p_date, coalesce(item.object_id::text, item.object_name), 'photos'),
      'foreman', 'high', 'foreman', now(), null
    );
    v_inserted := v_inserted + 1;
  end loop;

  if v_hour >= 16 then
    for item in
      select object_row.id as object_id, object_row.name as object_name,
             count(employee.id)::integer as item_count
      from public.objects object_row
      join public.employees employee
        on employee.company_id = object_row.company_id
       and employee.object_id = object_row.id
       and employee.is_active
       and employee.archived_at is null
      where object_row.company_id = p_company_id
        and object_row.is_active
        and not exists (
          select 1 from public.attendance attendance_row
          where attendance_row.company_id = employee.company_id
            and attendance_row.employee_id = employee.id
            and attendance_row.work_date = p_date
            and attendance_row.deleted_at is null
            and attendance_row.shifts > 0
        )
      group by object_row.id, object_row.name
    loop
      perform private.insert_operational_notification(
        p_company_id,
        'Табель заполнен не полностью',
        format('На объекте «%s» без положительной отметки за сегодня: %s сотрудников.', item.object_name, item.item_count),
        item.object_name,
        'operational_timesheet_missing',
        format('%s:%s:%s', p_date, item.object_id, 'timesheet'),
        'foreman', 'high', 'foreman', now(), null
      );
      v_inserted := v_inserted + 1;
    end loop;
  end if;

  for item in
    select object_row.id as object_id, object_row.name as object_name,
           count(employee.id)::integer as item_count
    from public.objects object_row
    join public.employees employee
      on employee.company_id = object_row.company_id
     and employee.object_id = object_row.id
     and employee.is_active
     and employee.archived_at is null
     and coalesce(employee.daily_rate, 0) <= 0
    where object_row.company_id = p_company_id
    group by object_row.id, object_row.name
  loop
    perform private.insert_operational_notification(
      p_company_id,
      'Не назначена ставка',
      format('На объекте «%s» без дневной ставки: %s сотрудников.', item.object_name, item.item_count),
      item.object_name,
      'operational_missing_rate',
      format('%s:%s:%s', p_date, item.object_id, 'rate'),
      'accountant', 'high', 'accountant', now(), null
    );
    v_inserted := v_inserted + 1;
  end loop;

  for item in
    with accrued as (
      select employee.id as employee_id,
             sum(coalesce(attendance_row.shifts, 0) * coalesce(employee.daily_rate, 0))::numeric as accrued
      from public.employees employee
      join public.attendance attendance_row
        on attendance_row.company_id = employee.company_id
       and attendance_row.employee_id = employee.id
       and attendance_row.work_date between v_month_start and v_month_end
       and attendance_row.deleted_at is null
      where employee.company_id = p_company_id
        and employee.is_active
        and employee.archived_at is null
      group by employee.id
    ), paid as (
      select payment.employee_id, sum(coalesce(payment.amount, 0))::numeric as paid
      from public.payments payment
      where payment.company_id = p_company_id
        and payment.payment_date between v_month_start and v_month_end
        and payment.deleted_at is null
      group by payment.employee_id
    ), balances as (
      select accrued.employee_id,
             greatest(accrued.accrued - coalesce(paid.paid, 0), 0)::numeric as balance
      from accrued
      left join paid on paid.employee_id = accrued.employee_id
      where accrued.accrued - coalesce(paid.paid, 0) > 0.5
    )
    select count(*)::integer as item_count,
           coalesce(sum(balance), 0)::numeric as total_amount
    from balances
    having count(*) > 0
  loop
    perform private.insert_operational_notification(
      p_company_id,
      'Есть расчётный остаток по выплатам',
      format('За текущий месяц положительный остаток у %s сотрудников на сумму около %s ₽. Сверь табель, выплаты и чеки.', item.item_count, round(item.total_amount)),
      '',
      'operational_payment_debt',
      format('%s:%s', to_char(p_date, 'YYYY-MM'), 'payment-debt'),
      'accountant', 'high', 'accountant', now(), null
    );
    v_inserted := v_inserted + 1;
  end loop;

  for item in
    select count(*)::integer as item_count,
           count(*) filter (where document.expires_on < p_date)::integer as expired_count
    from public.legal_documents document
    where document.company_id = p_company_id
      and document.archived_at is null
      and document.expires_on is not null
      and document.expires_on <= p_date + 30
    having count(*) > 0
  loop
    perform private.insert_operational_notification(
      p_company_id,
      'Проверь сроки документов',
      format('Просроченных или заканчивающихся в течение 30 дней документов: %s. Уже просрочено: %s.', item.item_count, item.expired_count),
      '',
      'operational_document_deadline',
      format('%s:%s', p_date, 'document-deadline'),
      'lawyer',
      case when item.expired_count > 0 then 'critical' else 'high' end,
      'lawyer', now(), null
    );
    v_inserted := v_inserted + 1;
  end loop;

  for item in
    select count(*)::integer as item_count
    from public.legal_documents document
    where document.company_id = p_company_id
      and document.archived_at is null
      and document.requires_manager_approval
      and document.approval_status = 'pending'
    having count(*) > 0
  loop
    perform private.insert_operational_notification(
      p_company_id,
      'Документы ожидают согласования',
      format('Ожидают согласования руководителя: %s документов.', item.item_count),
      '',
      'operational_document_approval',
      format('%s:%s', p_date, 'document-approval'),
      'lawyer', 'high', 'lawyer', now(), null
    );
    v_inserted := v_inserted + 1;
  end loop;

  return v_inserted;
end;
$$;

create or replace function private.refresh_all_operational_notifications()
returns integer
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  company_row record;
  v_total integer := 0;
begin
  for company_row in
    select company.id from public.companies company where company.status = 'active'
  loop
    v_total := v_total + private.refresh_operational_notifications_for_company(company_row.id);
  end loop;
  return v_total;
end;
$$;

create or replace function public.refresh_operational_notifications()
returns integer
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
begin
  if v_company_id is null then
    raise exception 'Не выбрана активная компания';
  end if;
  if not public.current_user_has_permission('notifications.center.view') then
    raise exception 'Нет доступа к центру уведомлений';
  end if;
  return private.refresh_operational_notifications_for_company(v_company_id);
end;
$$;

create or replace function public.create_ai_draft_ready_notification(
  p_title text,
  p_action_type text,
  p_action_id text
)
returns uuid
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_role text := public.current_user_role();
  v_source_role text;
  v_notification_id uuid;
begin
  if v_company_id is null or auth.uid() is null then
    raise exception 'Требуется вход в активную компанию';
  end if;
  if not public.current_user_has_permission('ai.use') then
    raise exception 'Нет доступа к ИИ-помощнику';
  end if;
  if nullif(btrim(coalesce(p_action_id, '')), '') is null then
    raise exception 'Не указан идентификатор черновика';
  end if;

  v_source_role := case
    when v_role in ('foreman', 'hr', 'accountant', 'lawyer') then v_role
    else 'admin'
  end;

  insert into public.app_notifications(
    company_id, title, body, actor_user_id, actor_name, actor_email,
    object_name, entity_type, entity_id, target_user_id, target_role,
    requires_action, due_at, priority, source_role, is_push_only,
    push_requested
  ) values (
    v_company_id,
    left(coalesce(nullif(btrim(p_title), ''), 'ИИ подготовил черновик'), 220),
    left(format('Черновик действия «%s» готов к проверке и подтверждению.', coalesce(nullif(btrim(p_action_type), ''), 'действие')), 1200),
    auth.uid(),
    'ИИ-помощник',
    '',
    '',
    'ai_draft',
    p_action_id,
    auth.uid(),
    null,
    true,
    now(),
    'normal',
    v_source_role,
    false,
    true
  )
  on conflict do nothing
  returning id into v_notification_id;

  if v_notification_id is null then
    select notification.id into v_notification_id
    from public.app_notifications notification
    where notification.company_id = v_company_id
      and notification.entity_type = 'ai_draft'
      and notification.entity_id = p_action_id
      and notification.target_user_id = auth.uid()
    order by notification.created_at desc
    limit 1;
  end if;

  return v_notification_id;
end;
$$;

create or replace function public.notification_event_group(p_entity_type text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select case
    when lower(coalesce(p_entity_type, '')) = 'ai_draft' then 'system'
    when lower(coalesce(p_entity_type, '')) in (
      'operational_overdue_tasks',
      'operational_missing_photos'
    ) then 'tasks'
    when lower(coalesce(p_entity_type, '')) = 'operational_timesheet_missing' then 'attendance'
    when lower(coalesce(p_entity_type, '')) = 'operational_missing_rate' then 'employees'
    when lower(coalesce(p_entity_type, '')) = 'operational_payment_debt' then 'payments'
    when lower(coalesce(p_entity_type, '')) in (
      'operational_document_deadline',
      'operational_document_approval'
    ) then 'legal'
    when lower(coalesce(p_entity_type, '')) in (
      'employee', 'employee_comment', 'employee_profile'
    ) then 'employees'
    when lower(coalesce(p_entity_type, '')) in (
      'attendance', 'timesheet', 'timesheet_missing'
    ) then 'attendance'
    when lower(coalesce(p_entity_type, '')) in (
      'payment', 'payment_receipt', 'payment_missing_receipt'
    ) then 'payments'
    when lower(coalesce(p_entity_type, '')) in (
      'task', 'task_photo', 'task_assignee', 'task_missing_photo'
    ) then 'tasks'
    when lower(coalesce(p_entity_type, '')) in (
      'legal_document', 'legal_matter', 'legal_report', 'legal_approval'
    ) then 'legal'
    when lower(coalesce(p_entity_type, '')) in (
      'recruitment_application', 'recruitment_document',
      'recruitment_message', 'recruitment_vacancy',
      'employee_mobilization'
    ) then 'recruitment'
    else 'system'
  end;
$$;

revoke all on function private.insert_operational_notification(uuid,text,text,text,text,text,text,text,text,timestamptz,uuid) from public, anon, authenticated;
revoke all on function private.refresh_operational_notifications_for_company(uuid,date) from public, anon, authenticated;
revoke all on function private.refresh_all_operational_notifications() from public, anon, authenticated;
revoke all on function public.refresh_operational_notifications() from public, anon;
revoke all on function public.create_ai_draft_ready_notification(text,text,text) from public, anon;
grant execute on function public.refresh_operational_notifications() to authenticated;
grant execute on function public.create_ai_draft_ready_notification(text,text,text) to authenticated;
