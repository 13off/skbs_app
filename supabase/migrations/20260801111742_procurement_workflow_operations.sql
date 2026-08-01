create or replace function public.save_procurement_request(p_request jsonb, p_items jsonb)
returns uuid
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_user_id uuid := auth.uid();
  v_request_id uuid;
  v_object_id uuid;
  v_supplier_id uuid;
  v_title text := btrim(coalesce(p_request->>'title',''));
  v_priority text := lower(btrim(coalesce(p_request->>'priority','normal')));
  v_needed_by date;
  v_expected_delivery_at timestamptz;
  v_invoice_number text := btrim(coalesce(p_request->>'invoice_number',''));
  v_comment text := btrim(coalesce(p_request->>'comment',''));
  v_item jsonb;
  v_total numeric(14,2) := 0;
  v_count integer := 0;
  v_current_status text;
begin
  if v_user_id is null or v_company_id is null then
    raise exception 'Требуется вход в активную компанию';
  end if;
  if not public.current_user_has_permission('procurement.requests.create') then
    raise exception 'Нет права создавать заявки на снабжение';
  end if;
  if char_length(v_title) < 2 then raise exception 'Укажите название заявки'; end if;
  if v_priority not in ('low','normal','high','urgent') then raise exception 'Неизвестный приоритет'; end if;
  begin v_object_id := nullif(p_request->>'object_id','')::uuid; exception when others then v_object_id := null; end;
  if v_object_id is null or not exists (
    select 1 from public.objects o where o.id=v_object_id and o.company_id=v_company_id and o.is_active=true
  ) then raise exception 'Выберите действующий объект'; end if;
  if public.current_user_role() = 'foreman' and not public.current_user_has_object_scope(v_object_id) then
    raise exception 'Нет доступа к выбранному объекту';
  end if;
  begin v_supplier_id := nullif(p_request->>'supplier_id','')::uuid; exception when others then v_supplier_id := null; end;
  if v_supplier_id is not null and not exists (
    select 1 from public.procurement_suppliers s where s.id=v_supplier_id and s.company_id=v_company_id and s.is_active=true
  ) then raise exception 'Поставщик не найден'; end if;
  begin v_needed_by := nullif(p_request->>'needed_by','')::date; exception when others then v_needed_by := null; end;
  begin v_expected_delivery_at := nullif(p_request->>'expected_delivery_at','')::timestamptz; exception when others then v_expected_delivery_at := null; end;
  begin v_request_id := nullif(p_request->>'id','')::uuid; exception when others then v_request_id := null; end;

  if jsonb_typeof(coalesce(p_items,'[]'::jsonb)) <> 'array' or jsonb_array_length(coalesce(p_items,'[]'::jsonb)) = 0 then
    raise exception 'Добавьте хотя бы одну позицию';
  end if;

  for v_item in select value from jsonb_array_elements(coalesce(p_items,'[]'::jsonb)) loop
    if btrim(coalesce(v_item->>'name','')) = '' then raise exception 'У позиции не указано название'; end if;
    if coalesce((v_item->>'quantity')::numeric,0) <= 0 then raise exception 'Количество должно быть больше нуля'; end if;
    v_total := v_total + coalesce((v_item->>'quantity')::numeric,0) * coalesce((v_item->>'estimated_unit_price')::numeric,0);
    v_count := v_count + 1;
  end loop;

  if v_request_id is null then
    insert into public.procurement_requests(
      company_id, object_id, requested_by, supplier_id, title, status, priority,
      needed_by, expected_delivery_at, total_amount, invoice_number, comment
    ) values (
      v_company_id, v_object_id, v_user_id, v_supplier_id, v_title, 'submitted', v_priority,
      v_needed_by, v_expected_delivery_at, round(v_total,2), v_invoice_number, v_comment
    ) returning id into v_request_id;
  else
    select r.status into v_current_status
    from public.procurement_requests r
    where r.id=v_request_id and r.company_id=v_company_id
      and (public.current_user_role() <> 'foreman' or public.current_user_has_object_scope(r.object_id))
    for update;
    if not found then raise exception 'Заявка не найдена'; end if;
    if v_current_status in ('delivered','canceled') then raise exception 'Закрытую заявку нельзя редактировать'; end if;
    if not public.current_user_has_permission('procurement.requests.edit') then raise exception 'Нет права изменять заявку'; end if;
    update public.procurement_requests set
      object_id=v_object_id, supplier_id=v_supplier_id, title=v_title, priority=v_priority,
      needed_by=v_needed_by, expected_delivery_at=v_expected_delivery_at,
      total_amount=round(v_total,2), invoice_number=v_invoice_number, comment=v_comment
    where id=v_request_id and company_id=v_company_id;
    delete from public.procurement_request_items where request_id=v_request_id and company_id=v_company_id;
  end if;

  v_count := 0;
  for v_item in select value from jsonb_array_elements(p_items) loop
    insert into public.procurement_request_items(
      company_id, request_id, name, quantity, unit, estimated_unit_price,
      actual_unit_price, ordered_quantity, delivered_quantity, note, sort_order
    ) values (
      v_company_id, v_request_id, btrim(v_item->>'name'),
      (v_item->>'quantity')::numeric,
      coalesce(nullif(btrim(v_item->>'unit'),''),'шт.'),
      coalesce((v_item->>'estimated_unit_price')::numeric,0),
      coalesce((v_item->>'actual_unit_price')::numeric,0),
      coalesce((v_item->>'ordered_quantity')::numeric,0),
      coalesce((v_item->>'delivered_quantity')::numeric,0),
      btrim(coalesce(v_item->>'note','')), v_count
    );
    v_count := v_count + 1;
  end loop;
  return v_request_id;
end;
$$;

create or replace function public.set_procurement_request_status(p_request_id uuid, p_status text)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_request public.procurement_requests%rowtype;
  v_next text := lower(btrim(coalesce(p_status,'')));
begin
  if auth.uid() is null or v_company_id is null then raise exception 'Требуется вход в компанию'; end if;
  if not public.current_user_has_permission('procurement.requests.edit') then raise exception 'Нет права менять состояние заявки'; end if;
  select * into v_request from public.procurement_requests r
  where r.id=p_request_id and r.company_id=v_company_id
    and (public.current_user_role() <> 'foreman' or public.current_user_has_object_scope(r.object_id))
  for update;
  if not found then raise exception 'Заявка не найдена'; end if;
  if v_next = 'approved' and not public.current_user_has_permission('procurement.requests.approve') then
    raise exception 'Нет права согласовывать заявку';
  end if;
  if v_next = 'canceled' then
    if v_request.status in ('delivered','canceled') then raise exception 'Заявка уже закрыта'; end if;
  elsif not (
    (v_request.status='draft' and v_next='submitted') or
    (v_request.status='submitted' and v_next='approved') or
    (v_request.status='approved' and v_next='purchasing') or
    (v_request.status='purchasing' and v_next='ordered') or
    (v_request.status='ordered' and v_next='in_delivery') or
    (v_request.status='in_delivery' and v_next='delivered')
  ) then
    raise exception 'Недопустимый переход статуса: % → %', v_request.status, v_next;
  end if;
  update public.procurement_requests set
    status=v_next,
    assigned_to=case when v_next in ('approved','purchasing','ordered','in_delivery') then coalesce(assigned_to,auth.uid()) else assigned_to end,
    ordered_at=case when v_next='ordered' then now() else ordered_at end,
    delivered_at=case when v_next='delivered' then now() else delivered_at end,
    updated_at=now()
  where id=p_request_id;
  return jsonb_build_object('id',p_request_id,'status',v_next);
end;
$$;

revoke all on function public.save_procurement_request(jsonb,jsonb) from public, anon;
grant execute on function public.save_procurement_request(jsonb,jsonb) to authenticated, service_role;
revoke all on function public.set_procurement_request_status(uuid,text) from public, anon;
grant execute on function public.set_procurement_request_status(uuid,text) to authenticated, service_role;

drop trigger if exists app_data_broadcast_after_change on public.procurement_suppliers;
create trigger app_data_broadcast_after_change after insert or update or delete on public.procurement_suppliers
for each row execute function private.broadcast_app_data_change();
drop trigger if exists app_data_broadcast_after_change on public.procurement_requests;
create trigger app_data_broadcast_after_change after insert or update or delete on public.procurement_requests
for each row execute function private.broadcast_app_data_change();
drop trigger if exists app_data_broadcast_after_change on public.procurement_request_items;
create trigger app_data_broadcast_after_change after insert or update or delete on public.procurement_request_items
for each row execute function private.broadcast_app_data_change();

create or replace function public.normalize_notification_role(p_role text)
returns text language sql immutable set search_path=public,pg_temp as $$
select case lower(btrim(coalesce(p_role,'')))
  when 'owner' then 'admin' when 'developer' then 'admin'
  when 'accounting' then 'accountant' when 'accountant' then 'accountant'
  when 'admin' then 'admin' when 'foreman' then 'foreman' when 'hr' then 'hr'
  when 'lawyer' then 'lawyer' when 'procurement' then 'procurement'
  else 'admin' end;
$$;

create or replace function public.notification_role_for_entity(p_entity_type text)
returns text language sql immutable set search_path=public,pg_temp as $$
select case
  when coalesce(p_entity_type,'') in ('attendance','tasks','task_assignees','task_photos','brigade_photo','foreman_reminder') then 'foreman'
  when coalesce(p_entity_type,'') in ('recruitment_application','recruitment_applications','recruitment_message','recruitment_messages','recruitment_document','recruitment_documents','employees','employee_private_data','hr_reminder') then 'hr'
  when coalesce(p_entity_type,'') in ('payments','payment_receipts','accountant_reminder') then 'accountant'
  when coalesce(p_entity_type,'') like 'legal_%' or coalesce(p_entity_type,'') in ('legal_document','legal_matter','lawyer_reminder') then 'lawyer'
  when coalesce(p_entity_type,'') like 'procurement_%' or coalesce(p_entity_type,'') in ('procurement_request','procurement_supplier','procurement_delivery') then 'procurement'
  else 'admin' end;
$$;

do $$
declare v_definition text;
begin
  select pg_get_functiondef(p.oid) into v_definition
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='update_company_member_access'
    and pg_get_function_identity_arguments(p.oid)='p_company_id uuid, p_user_id uuid, p_role text, p_profession text, p_object_id uuid';
  if v_definition is not null then
    v_definition := replace(v_definition,
      $old$p_role not in ('admin', 'developer', 'foreman', 'lawyer', 'accountant', 'hr')$old$,
      $new$p_role not in ('admin', 'developer', 'foreman', 'lawyer', 'accountant', 'hr', 'procurement')$new$);
    execute v_definition;
  end if;

  select pg_get_functiondef(p.oid) into v_definition
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='save_role_permission_override'
    and pg_get_function_identity_arguments(p.oid)='p_scope text, p_role_code text, p_permission_code text, p_is_allowed boolean, p_object_id uuid';
  if v_definition is not null then
    v_definition := replace(v_definition,
      $old$p_role_code not in ('admin','developer','foreman','hr','accountant','lawyer')$old$,
      $new$p_role_code not in ('admin','developer','foreman','hr','accountant','lawyer','procurement')$new$);
    execute v_definition;
  end if;

  select pg_get_functiondef(p.oid) into v_definition
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='get_role_permission_center'
    and pg_get_function_identity_arguments(p.oid)='';
  if v_definition is not null then
    v_definition := replace(v_definition,
      $old$jsonb_build_object('code','lawyer','title','Юрист')$old$,
      $new$jsonb_build_object('code','lawyer','title','Юрист'), jsonb_build_object('code','procurement','title','Снабженец')$new$);
    execute v_definition;
  end if;
end;
$$;
