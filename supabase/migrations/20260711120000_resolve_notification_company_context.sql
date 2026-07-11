-- SECURITY DEFINER business triggers may run without an end-user JWT (for
-- example, while an Edge Function creates an invited profile). Resolve the
-- tenant before the NOT NULL check so those writes never fall back to another
-- company and never block the business operation.

create or replace function public.resolve_notification_company_context()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_entity_uuid uuid;
begin
  if new.company_id is not null then return new; end if;

  new.company_id := public.current_user_company_id();
  if new.company_id is not null then return new; end if;

  if coalesce(new.entity_id, '') ~
      '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$' then
    v_entity_uuid := new.entity_id::uuid;
  end if;

  if new.entity_type = 'user_profiles' and v_entity_uuid is not null then
    select p.active_company_id into new.company_id
    from public.user_profiles p where p.id = v_entity_uuid;
  elsif new.entity_type = 'objects' and v_entity_uuid is not null then
    select o.company_id into new.company_id
    from public.objects o where o.id = v_entity_uuid;
  elsif new.entity_type = 'employees' and v_entity_uuid is not null then
    select e.company_id into new.company_id
    from public.employees e where e.id = v_entity_uuid;
  elsif new.entity_type = 'tasks' and v_entity_uuid is not null then
    select t.company_id into new.company_id
    from public.tasks t where t.id = v_entity_uuid;
  elsif new.entity_type = 'payments' and v_entity_uuid is not null then
    select p.company_id into new.company_id
    from public.payments p where p.id = v_entity_uuid;
  elsif new.entity_type = 'payment_receipts' and v_entity_uuid is not null then
    select r.company_id into new.company_id
    from public.payment_receipts r where r.id = v_entity_uuid;
  elsif new.entity_type = 'task_photos' and v_entity_uuid is not null then
    select p.company_id into new.company_id
    from public.task_photos p where p.id = v_entity_uuid;
  end if;

  if new.company_id is null and new.actor_user_id is not null then
    select m.company_id into new.company_id
    from public.company_memberships m
    where m.user_id = new.actor_user_id and m.is_active = true
    order by m.created_at, m.company_id
    limit 1;
  end if;

  if new.company_id is null then
    raise exception 'Не удалось определить компанию уведомления %', new.entity_type;
  end if;

  return new;
end;
$$;

drop trigger if exists app_notifications_resolve_company
on public.app_notifications;
create trigger app_notifications_resolve_company
before insert on public.app_notifications
for each row execute function public.resolve_notification_company_context();

revoke all on function public.resolve_notification_company_context()
from public, anon, authenticated;

