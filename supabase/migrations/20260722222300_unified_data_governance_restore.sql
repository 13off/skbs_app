create or replace function public.restore_governance_entity(
  p_entity_type text,
  p_entity_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_type text := lower(btrim(coalesce(p_entity_type, '')));
  v_object_id uuid;
begin
  if v_company_id is null
     or not public.current_user_has_permission(
       'system.recycle_bin.manage'
     ) then
    raise exception 'Недостаточно прав для восстановления данных';
  end if;

  if v_type = 'task' then
    perform public.restore_task(p_entity_id);
  elsif v_type = 'attendance' then
    update public.attendance
       set deleted_at = null,
           deleted_by = null,
           delete_reason = '',
           restored_at = now(),
           restored_by = auth.uid(),
           updated_at = now()
     where id = p_entity_id
       and company_id = v_company_id
       and deleted_at is not null;
    if not found then raise exception 'Запись табеля не найдена в корзине'; end if;
  elsif v_type = 'payment' then
    update public.payments
       set deleted_at = null,
           deleted_by = null,
           delete_reason = '',
           restored_at = now(),
           restored_by = auth.uid(),
           updated_at = now()
     where id = p_entity_id
       and company_id = v_company_id
       and deleted_at is not null;
    if not found then raise exception 'Выплата не найдена в корзине'; end if;
  elsif v_type = 'milestone' then
    update public.project_milestones
       set deleted_at = null,
           deleted_by = null,
           delete_reason = '',
           restored_at = now(),
           restored_by = auth.uid(),
           updated_at = now()
     where id = p_entity_id
       and company_id = v_company_id
       and deleted_at is not null;
    if not found then raise exception 'Цель или этап не найдены в корзине'; end if;
  elsif v_type = 'employee' then
    update public.employees
       set is_active = true,
           archived_at = null,
           updated_at = now()
     where id = p_entity_id
       and company_id = v_company_id
       and not is_active;
    if not found then raise exception 'Сотрудник не найден в архиве'; end if;
  elsif v_type = 'object' then
    select id into v_object_id
      from public.objects
     where id = p_entity_id
       and company_id = v_company_id
       and not is_active;
    if not found then raise exception 'Объект не найден в архиве'; end if;
    if not public.company_can_add_object(v_company_id) then
      raise exception 'Лимит активных объектов по тарифу исчерпан';
    end if;
    update public.objects
       set is_active = true,
           updated_at = now()
     where id = v_object_id;
  elsif v_type = 'legal_document' then
    update public.legal_documents
       set archived_at = null,
           updated_at = now(),
           updated_by = auth.uid()
     where id = p_entity_id
       and company_id = v_company_id
       and archived_at is not null;
    if not found then raise exception 'Документ не найден в архиве'; end if;
  else
    raise exception 'Неизвестный тип записи';
  end if;

  return public.get_data_governance_center(null, null, 250);
end;
$$;

revoke all on function public.get_data_governance_center(uuid, text, integer)
  from public, anon;
revoke all on function public.restore_governance_entity(text, uuid)
  from public, anon;

grant execute on function public.get_data_governance_center(uuid, text, integer)
  to authenticated;
grant execute on function public.restore_governance_entity(text, uuid)
  to authenticated;
