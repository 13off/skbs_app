-- Таблица уведомлений AppСтрой
-- Выполнить в Supabase SQL Editor один раз.

create table if not exists public.app_notifications (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null default '',
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_name text not null default '',
  actor_email text not null default '',
  object_name text not null default '',
  entity_type text not null default '',
  entity_id text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists app_notifications_created_at_idx
  on public.app_notifications (created_at desc);

create index if not exists app_notifications_object_name_idx
  on public.app_notifications (object_name);

alter table public.app_notifications enable row level security;

drop policy if exists "app_notifications_select_authenticated" on public.app_notifications;
create policy "app_notifications_select_authenticated"
  on public.app_notifications
  for select
  to authenticated
  using (true);

drop policy if exists "app_notifications_insert_authenticated" on public.app_notifications;
create policy "app_notifications_insert_authenticated"
  on public.app_notifications
  for insert
  to authenticated
  with check (true);

create or replace function public.app_notify_change()
returns trigger
language plpgsql
security definer
set search_path = public
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
  v_entity_type text := TG_TABLE_NAME;
  v_employee_id text := '';
  v_employee_name text := '';
begin
  if TG_OP = 'DELETE' then
    v_row := to_jsonb(OLD);
  else
    v_row := to_jsonb(NEW);
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

  if TG_TABLE_NAME = 'objects' then
    v_object_name := coalesce(v_row ->> 'name', v_object_name);
  end if;

  if TG_TABLE_NAME = 'employees' then
    v_employee_name := coalesce(v_row ->> 'fio', v_employee_name);

    if TG_OP = 'INSERT' then
      v_title := 'Добавлен сотрудник';
    elsif TG_OP = 'UPDATE' then
      if coalesce(OLD.is_active, true) <> coalesce(NEW.is_active, true) then
        if coalesce(NEW.is_active, true) then
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

  elsif TG_TABLE_NAME = 'tasks' then
    if TG_OP = 'INSERT' then
      v_title := 'Добавлена задача';
    elsif TG_OP = 'UPDATE' then
      v_title := 'Изменена задача';
    else
      v_title := 'Удалена задача';
    end if;

    v_body := concat_ws(
      ' • ',
      nullif(v_row ->> 'axes', ''),
      nullif(v_row ->> 'work', ''),
      nullif(v_row ->> 'status', '')
    );

  elsif TG_TABLE_NAME = 'task_assignees' then
    if TG_OP = 'DELETE' then
      v_title := 'Исполнитель снят с задачи';
    else
      v_title := 'Назначен исполнитель задачи';
    end if;

    v_body := concat_ws(' • ', nullif(v_employee_name, ''), 'Задача: ' || coalesce(v_row ->> 'task_id', ''));

  elsif TG_TABLE_NAME = 'task_photos' then
    if TG_OP = 'DELETE' then
      v_title := 'Удалено фото задачи';
    else
      v_title := 'Добавлено фото задачи';
    end if;

    v_body := concat_ws(' • ', nullif(v_row ->> 'original_name', ''), 'Задача: ' || coalesce(v_row ->> 'task_id', ''));

  elsif TG_TABLE_NAME = 'payments' then
    if TG_OP = 'INSERT' then
      v_title := 'Добавлена выплата';
    elsif TG_OP = 'UPDATE' then
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

  elsif TG_TABLE_NAME = 'payment_receipts' then
    if TG_OP = 'DELETE' then
      v_title := 'Удалён чек выплаты';
    else
      v_title := 'Добавлен чек выплаты';
    end if;

    v_body := concat_ws(' • ', nullif(v_employee_name, ''), nullif(v_row ->> 'file_name', ''));

  elsif TG_TABLE_NAME = 'objects' then
    if TG_OP = 'INSERT' then
      v_title := 'Добавлен объект';
    elsif TG_OP = 'UPDATE' then
      if coalesce(OLD.is_active, true) <> coalesce(NEW.is_active, true) then
        if coalesce(NEW.is_active, true) then
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

  elsif TG_TABLE_NAME = 'employee_private_data' then
    if TG_OP = 'DELETE' then
      v_title := 'Удалены личные данные сотрудника';
    elsif TG_OP = 'INSERT' then
      v_title := 'Добавлены личные данные сотрудника';
    else
      v_title := 'Изменены личные данные сотрудника';
    end if;

    v_body := concat_ws(' • ', nullif(v_employee_name, ''), 'Карточка сотрудника');

  elsif TG_TABLE_NAME = 'user_profiles' then
    if TG_OP = 'INSERT' then
      v_title := 'Добавлен пользователь';
    elsif TG_OP = 'UPDATE' then
      v_title := 'Изменён пользователь';
    else
      v_title := 'Удалён пользователь';
    end if;

    v_body := concat_ws(' • ', nullif(v_row ->> 'full_name', ''), nullif(v_row ->> 'email', ''));
  end if;

  insert into public.app_notifications (
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

  if TG_OP = 'DELETE' then
    return OLD;
  end if;

  return NEW;
end;
$$;

-- Табель больше не пишется построчно через SQL-триггер.
-- Одно общее уведомление создаёт приложение после сохранения табеля.
do $$
begin
  if to_regclass('public.attendance') is not null then
    drop trigger if exists app_notify_attendance on public.attendance;
  end if;
end;
$$;

-- Подключение триггеров только к существующим таблицам.
do $$
declare
  v_table_name text;
  v_trigger_name text;
begin
  foreach v_table_name in array array[
    'employees',
    'tasks',
    'task_assignees',
    'task_photos',
    'payments',
    'payment_receipts',
    'objects',
    'employee_private_data',
    'user_profiles'
  ]
  loop
    if to_regclass('public.' || v_table_name) is not null then
      v_trigger_name := 'app_notify_' || v_table_name;

      execute format(
        'drop trigger if exists %I on public.%I',
        v_trigger_name,
        v_table_name
      );

      execute format(
        'create trigger %I after insert or update or delete on public.%I for each row execute function public.app_notify_change()',
        v_trigger_name,
        v_table_name
      );
    end if;
  end loop;
end;
$$;
