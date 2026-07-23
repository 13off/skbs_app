create or replace function private.validate_dispatcher_summary_settings()
returns trigger
language plpgsql
security definer
set search_path to public, pg_temp
as $body$
declare
  v_object_name text;
begin
  if nullif(btrim(new.timezone), '') is null then
    raise exception 'Неизвестный часовой пояс: %', new.timezone;
  end if;

  begin
    perform pg_catalog.timezone(new.timezone, now());
  exception when invalid_parameter_value then
    raise exception 'Неизвестный часовой пояс: %', new.timezone;
  end;

  new.weekdays := array(
    select distinct value from unnest(new.weekdays) value order by value
  );
  new.recipient_roles := array(
    select distinct value from unnest(new.recipient_roles) value order by value
  );

  if new.object_id is not null then
    select object_row.name into v_object_name
    from public.objects object_row
    where object_row.id = new.object_id
      and object_row.company_id = new.company_id
      and object_row.is_active = true;
    if not found then
      raise exception 'Выбранный объект не найден или отключён';
    end if;
    new.object_name := v_object_name;
  else
    new.object_name := '';
    if new.enabled then
      raise exception 'Выберите объект для ежедневной сводки';
    end if;
  end if;

  new.updated_at := now();
  new.updated_by := coalesce(auth.uid(), new.updated_by);
  return new;
end;
$body$;
