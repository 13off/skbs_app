alter table public.app_notifications
  alter column source_role drop default;

create or replace function public.notification_visible_for_current_user(
  p_source_role text,
  p_target_user_id uuid,
  p_target_role text,
  p_entity_type text,
  p_object_name text
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    auth.uid() is not null
    and (
      p_target_user_id = auth.uid()
      or (
        public.is_admin()
        and public.normalize_notification_role(p_source_role) = any(public.current_admin_notification_roles())
      )
      or (
        not public.is_admin()
        and p_target_user_id is null
        and public.normalize_notification_role(p_source_role) = public.normalize_notification_role(public.current_user_role())
        and (
          p_target_role is null
          or public.normalize_notification_role(p_target_role) = public.normalize_notification_role(public.current_user_role())
        )
        and (
          public.normalize_notification_role(public.current_user_role()) <> 'foreman'
          or (
            coalesce(p_entity_type, '') in (
              'attendance','tasks','task_assignees','task_photos',
              'brigade_photo','foreman_reminder',
              'legal_document','legal_matter','legal_reminder'
            )
            and public.can_access_object(coalesce(p_object_name, ''))
          )
        )
      )
    );
$$;

revoke all on function public.notification_visible_for_current_user(text, uuid, text, text, text) from public, anon;
grant execute on function public.notification_visible_for_current_user(text, uuid, text, text, text) to authenticated, service_role;

create or replace function public.set_my_notification_role_preferences(p_roles text[])
returns text[]
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_roles text[];
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Настройки ролей доступны только руководителю';
  end if;

  select coalesce(
    array_agg(
      distinct public.normalize_notification_role(value)
      order by public.normalize_notification_role(value)
    ),
    array[]::text[]
  )
  into v_roles
  from unnest(coalesce(p_roles, array[]::text[])) as value
  where lower(btrim(value)) in (
    'admin','owner','foreman','hr','accountant','accounting','lawyer'
  );

  insert into public.notification_role_preferences(
    company_id, user_id, selected_roles, updated_at
  )
  values(v_company_id, auth.uid(), v_roles, now())
  on conflict(company_id, user_id) do update
    set selected_roles = excluded.selected_roles,
        updated_at = now();

  return v_roles;
end;
$$;

revoke all on function public.set_my_notification_role_preferences(text[]) from public, anon;
grant execute on function public.set_my_notification_role_preferences(text[]) to authenticated;

create or replace function private.mark_draft_task_delete()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if old.is_draft then
    perform set_config('appstroy.suppress_draft_task_id', old.id::text, true);
  end if;
  return old;
end;
$$;

revoke all on function private.mark_draft_task_delete() from public, anon, authenticated;
grant execute on function private.mark_draft_task_delete() to service_role;

drop trigger if exists tasks_mark_draft_delete on public.tasks;
create trigger tasks_mark_draft_delete
before delete on public.tasks
for each row execute function private.mark_draft_task_delete();

create or replace function public.app_notify_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row jsonb;
  v_actor_user_id uuid;
  v_actor_name text := 'Пользователь';
  v_actor_email text := '';
  v_title text := 'Изменение';
  v_body text := '';
  v_object_name text := '';
  v_entity_id text := '';
  v_entity_type text := tg_table_name;
  v_employee_id text := '';
  v_employee_name text := '';
  v_task_id text := '';
  v_suppressed_draft_id text := coalesce(
    current_setting('appstroy.suppress_draft_task_id', true),
    ''
  );
begin
  if tg_op = 'DELETE' then
    v_row := to_jsonb(old);
  else
    v_row := to_jsonb(new);
  end if;

  v_task_id := coalesce(v_row ->> 'task_id', '');

  if tg_table_name = 'tasks' then
    if tg_op = 'INSERT' and coalesce(new.is_draft, false) then
      return new;
    end if;
    if tg_op = 'UPDATE' and coalesce(new.is_draft, false) then
      return new;
    end if;
    if tg_op = 'DELETE' and coalesce(old.is_draft, false) then
      return old;
    end if;
  elsif tg_table_name in ('task_assignees', 'task_photos') then
    if v_task_id <> '' and (
      v_task_id = v_suppressed_draft_id
      or exists (
        select 1
        from public.tasks draft_task
        where draft_task.id::text = v_task_id
          and draft_task.is_draft
      )
    ) then
      if tg_op = 'DELETE' then
        return old;
      end if;
      return new;
    end if;
  end if;

  v_actor_user_id := auth.uid();

  if v_actor_user_id is not null then
    select
      coalesce(nullif(trim(full_name), ''), nullif(trim(email), ''), 'Пользователь'),
      coalesce(email, '')
    into v_actor_name, v_actor_email
    from public.user_profiles
    where id = v_actor_user_id;
  end if;

  v_actor_name := coalesce(nullif(trim(v_actor_name), ''), 'Пользователь');
  v_actor_email := coalesce(v_actor_email, '');

  v_entity_id := coalesce(v_row ->> 'id', '');
  v_object_name := coalesce(v_row ->> 'object_name', '');
  v_employee_id := coalesce(v_row ->> 'employee_id', '');

  if v_employee_id <> '' then
    select
      coalesce(fio, ''),
      coalesce(object_name, v_object_name)
    into v_employee_name, v_object_name
    from public.employees
    where id::text = v_employee_id
    limit 1;
  end if;

  if v_object_name = '' and v_task_id <> '' then
    select coalesce(object_name, '')
    into v_object_name
    from public.tasks
    where id::text = v_task_id
    limit 1;
  end if;

  if tg_table_name = 'objects' then
    v_object_name := coalesce(v_row ->> 'name', v_object_name);
  end if;

  if tg_table_name = 'employees' then
    v_employee_name := coalesce(v_row ->> 'fio', v_employee_name);

    if tg_op = 'INSERT' then
      v_title := 'Добавлен сотрудник';
    elsif tg_op = 'UPDATE' then
      if coalesce(old.is_active, true) <> coalesce(new.is_active, true) then
        if coalesce(new.is_active, true) then
          v_title := 'Сотрудник восстановлен';
        else
          v_title := 'Сотрудник архивирован';
        end if;
      else
        v_title := 'Изменён сотрудник';
      end if;
    else
      v_title := 'Удалён сотрудник';
    end if;

    v_body := concat_ws(' • ', nullif(v_employee_name, ''), nullif(v_object_name, ''));

  elsif tg_table_name = 'tasks' then
    if tg_op = 'INSERT' then
      v_title := 'Добавлена задача';
    elsif tg_op = 'UPDATE' then
      if coalesce(old.is_draft, false) and not coalesce(new.is_draft, false) then
        v_title := 'Добавлена задача';
      else
        v_title := 'Изменена задача';
      end if;
    else
      v_title := 'Удалена задача';
    end if;

    v_body := concat_ws(
      ' • ',
      nullif(v_row ->> 'axes', ''),
      nullif(v_row ->> 'work', ''),
      nullif(v_row ->> 'status', '')
    );

  elsif tg_table_name = 'task_assignees' then
    if tg_op = 'DELETE' then
      v_title := 'Исполнитель снят с задачи';
    else
      v_title := 'Назначен исполнитель задачи';
    end if;

    v_body := concat_ws(
      ' • ',
      nullif(v_employee_name, ''),
      'Задача: ' || coalesce(v_row ->> 'task_id', '')
    );

  elsif tg_table_name = 'task_photos' then
    if tg_op = 'DELETE' then
      v_title := 'Удалено фото задачи';
    elsif coalesce(v_row ->> 'photo_stage', 'before') = 'after' then
      v_title := 'Добавлено фото «После»';
    else
      v_title := 'Добавлено фото «До»';
    end if;

    v_body := concat_ws(
      ' • ',
      nullif(v_row ->> 'original_name', ''),
      'Задача: ' || coalesce(v_row ->> 'task_id', '')
    );

  elsif tg_table_name = 'payments' then
    if tg_op = 'INSERT' then
      v_title := 'Добавлена выплата';
    elsif tg_op = 'UPDATE' then
      v_title := 'Изменена выплата';
    else
      v_title := 'Удалена выплата';
    end if;

    v_body := concat_ws(
      ' • ',
      nullif(v_employee_name, ''),
      'Сумма: ' || coalesce(v_row ->> 'amount', '0') || ' ₽',
      'Период: ' || coalesce(v_row ->> 'period_month', '') || '.' || coalesce(v_row ->> 'period_year', '')
    );

  elsif tg_table_name = 'payment_receipts' then
    if tg_op = 'DELETE' then
      v_title := 'Удалён чек выплаты';
    else
      v_title := 'Добавлен чек выплаты';
    end if;

    v_body := concat_ws(' • ', nullif(v_employee_name, ''), nullif(v_row ->> 'file_name', ''));

  elsif tg_table_name = 'objects' then
    if tg_op = 'INSERT' then
      v_title := 'Добавлен объект';
    elsif tg_op = 'UPDATE' then
      if coalesce(old.is_active, true) <> coalesce(new.is_active, true) then
        if coalesce(new.is_active, true) then
          v_title := 'Объект восстановлен';
        else
          v_title := 'Объект архивирован';
        end if;
      else
        v_title := 'Изменён объект';
      end if;
    else
      v_title := 'Удалён объект';
    end if;

    v_body := concat_ws(' • ', nullif(v_object_name, ''), nullif(v_row ->> 'address', ''));

  elsif tg_table_name = 'employee_private_data' then
    if tg_op = 'DELETE' then
      v_title := 'Удалены личные данные сотрудника';
    elsif tg_op = 'INSERT' then
      v_title := 'Добавлены личные данные сотрудника';
    else
      v_title := 'Изменены личные данные сотрудника';
    end if;

    v_body := concat_ws(' • ', nullif(v_employee_name, ''), 'Карточка сотрудника');

  elsif tg_table_name = 'user_profiles' then
    if tg_op = 'INSERT' then
      v_title := 'Добавлен пользователь';
    elsif tg_op = 'UPDATE' then
      v_title := 'Изменён пользователь';
    else
      v_title := 'Удалён пользователь';
    end if;

    v_body := concat_ws(
      ' • ',
      nullif(v_row ->> 'full_name', ''),
      nullif(v_row ->> 'email', '')
    );
  end if;

  insert into public.app_notifications(
    title,
    body,
    actor_user_id,
    actor_name,
    actor_email,
    object_name,
    entity_type,
    entity_id
  ) values (
    v_title,
    coalesce(v_body, ''),
    v_actor_user_id,
    v_actor_name,
    v_actor_email,
    coalesce(v_object_name, ''),
    v_entity_type,
    v_entity_id
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function public.app_notify_change() from public, anon, authenticated;
grant execute on function public.app_notify_change() to service_role;

create or replace function private.filter_draft_task_notifications()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.entity_type = 'tasks'
     and coalesce(new.entity_id, '') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
     and exists (
       select 1 from public.tasks t
       where t.id = new.entity_id::uuid and t.is_draft
     ) then
    return null;
  end if;

  if new.entity_type = 'task_photos'
     and coalesce(new.entity_id, '') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
     and exists (
       select 1
       from public.task_photos p
       join public.tasks t on t.id = p.task_id
       where p.id = new.entity_id::uuid
         and t.is_draft
     ) then
    return null;
  end if;

  return new;
end;
$$;

revoke all on function private.filter_draft_task_notifications() from public, anon, authenticated;
grant execute on function private.filter_draft_task_notifications() to service_role;
