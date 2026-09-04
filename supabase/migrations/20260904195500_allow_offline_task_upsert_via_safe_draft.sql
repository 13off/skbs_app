create or replace function private.validate_task_photo_requirements()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_policy jsonb;
  v_before_count integer;
  v_after_count integer;
begin
  v_policy := public.get_effective_task_policy(new.object_name);
  new.photo_requirements_enforced := coalesce(
    (v_policy ->> 'require_before_photo')::boolean,
    true
  );

  if tg_op = 'INSERT' then
    if new.created_by_user_id is null then
      new.created_by_user_id := auth.uid();
    end if;
    if not public.task_can_create_for_user(new.task_date, new.object_name) then
      raise exception 'Создание задачи на эту дату запрещено настройками объекта';
    end if;

    -- Offline-first replay sends the intended final state via idempotent
    -- upsert. Persist it as a safe draft first. The client writes assignees,
    -- links and photos, then publishes it with a separate UPDATE. This keeps
    -- the existing photo validation on draft -> final intact.
    if not coalesce(new.is_draft, false) then
      new.is_draft := true;
    end if;
    return new;
  end if;

  if not public.is_admin() then
    if not public.task_can_edit_for_user(old.id) then
      raise exception 'Редактирование задачи закрыто настройками объекта';
    end if;
    if new.object_name is distinct from old.object_name then
      raise exception 'Прораб не может переносить задачу между объектами';
    end if;
    if new.task_date is distinct from old.task_date
       and not coalesce((v_policy ->> 'foreman_can_edit_date')::boolean, true) then
      raise exception 'Изменение даты задачи запрещено настройками объекта';
    end if;
    if (new.axes is distinct from old.axes or new.work is distinct from old.work)
       and not coalesce((v_policy ->> 'foreman_can_edit_axes_work')::boolean, true) then
      raise exception 'Изменение осей и вида работ запрещено настройками объекта';
    end if;
    if new.status is distinct from old.status
       and not coalesce((v_policy ->> 'foreman_can_edit_status')::boolean, true) then
      raise exception 'Изменение статуса запрещено настройками объекта';
    end if;
  end if;

  if old.is_draft
     and not new.is_draft
     and coalesce((v_policy ->> 'require_before_photo')::boolean, true) then
    select count(*)
      into v_before_count
      from public.task_photos p
     where p.task_id = new.id
       and p.photo_stage = 'before';
    if v_before_count < coalesce((v_policy ->> 'min_before_photos')::integer, 1) then
      raise exception 'Добавьте необходимое количество фото «До»: %',
        coalesce((v_policy ->> 'min_before_photos')::integer, 1);
    end if;
  end if;

  if new.status = 'Выполнено'
     and old.status is distinct from new.status
     and coalesce((v_policy ->> 'require_after_photo_on_complete')::boolean, true) then
    select count(*)
      into v_after_count
      from public.task_photos p
     where p.task_id = new.id
       and p.photo_stage = 'after';
    if v_after_count < coalesce((v_policy ->> 'min_after_photos')::integer, 1) then
      raise exception 'Добавьте необходимое количество фото «После»: %',
        coalesce((v_policy ->> 'min_after_photos')::integer, 1);
    end if;
  end if;

  if new.status <> 'Выполнено'
     and not (old.is_draft and not new.is_draft)
     and new.task_date <= public.current_operational_date()
     and coalesce((v_policy ->> 'require_not_done_comment')::boolean, true)
     and btrim(coalesce(new.not_done_comment, '')) = '' then
    raise exception 'Укажите причину, почему задача не выполнена';
  end if;

  return new;
end;
$function$;
