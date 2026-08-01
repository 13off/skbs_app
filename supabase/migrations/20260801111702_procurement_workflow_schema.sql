create table if not exists public.procurement_suppliers (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null,
  inn text not null default '',
  contact_name text not null default '',
  phone text not null default '',
  email text not null default '',
  comment text not null default '',
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint procurement_suppliers_name_check check (char_length(btrim(name)) between 2 and 200),
  constraint procurement_suppliers_email_check check (email = '' or email like '%@%')
);

create unique index if not exists procurement_suppliers_company_name_uidx
  on public.procurement_suppliers(company_id, lower(btrim(name)));
create index if not exists procurement_suppliers_company_active_idx
  on public.procurement_suppliers(company_id, is_active, name);

create table if not exists public.procurement_requests (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  object_id uuid not null references public.objects(id) on delete restrict,
  object_name text not null default '',
  requested_by uuid references auth.users(id) on delete set null,
  assigned_to uuid references auth.users(id) on delete set null,
  supplier_id uuid references public.procurement_suppliers(id) on delete set null,
  title text not null,
  status text not null default 'submitted',
  priority text not null default 'normal',
  needed_by date,
  expected_delivery_at timestamptz,
  ordered_at timestamptz,
  delivered_at timestamptz,
  total_amount numeric(14,2) not null default 0,
  invoice_number text not null default '',
  comment text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint procurement_requests_title_check check (char_length(btrim(title)) between 2 and 240),
  constraint procurement_requests_status_check check (status = any(array['draft','submitted','approved','purchasing','ordered','in_delivery','delivered','canceled']::text[])),
  constraint procurement_requests_priority_check check (priority = any(array['low','normal','high','urgent']::text[])),
  constraint procurement_requests_total_check check (total_amount >= 0)
);

create index if not exists procurement_requests_company_status_idx
  on public.procurement_requests(company_id, status, updated_at desc);
create index if not exists procurement_requests_company_object_idx
  on public.procurement_requests(company_id, object_id, updated_at desc);
create index if not exists procurement_requests_needed_by_idx
  on public.procurement_requests(company_id, needed_by)
  where status not in ('delivered','canceled');
create index if not exists procurement_requests_supplier_idx
  on public.procurement_requests(company_id, supplier_id)
  where supplier_id is not null;

create table if not exists public.procurement_request_items (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  request_id uuid not null references public.procurement_requests(id) on delete cascade,
  name text not null,
  quantity numeric(14,3) not null default 1,
  unit text not null default 'шт.',
  estimated_unit_price numeric(14,2) not null default 0,
  actual_unit_price numeric(14,2) not null default 0,
  ordered_quantity numeric(14,3) not null default 0,
  delivered_quantity numeric(14,3) not null default 0,
  note text not null default '',
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint procurement_request_items_name_check check (char_length(btrim(name)) between 1 and 240),
  constraint procurement_request_items_quantity_check check (quantity > 0),
  constraint procurement_request_items_prices_check check (estimated_unit_price >= 0 and actual_unit_price >= 0),
  constraint procurement_request_items_delivery_check check (ordered_quantity >= 0 and delivered_quantity >= 0)
);

create index if not exists procurement_request_items_request_idx
  on public.procurement_request_items(request_id, sort_order, id);
create index if not exists procurement_request_items_company_idx
  on public.procurement_request_items(company_id, request_id);

create or replace function private.validate_procurement_supplier()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.company_id <> public.current_user_company_id() then
    raise exception 'Поставщик относится к другой компании';
  end if;
  new.name := btrim(new.name);
  new.inn := btrim(coalesce(new.inn,''));
  new.contact_name := btrim(coalesce(new.contact_name,''));
  new.phone := btrim(coalesce(new.phone,''));
  new.email := lower(btrim(coalesce(new.email,'')));
  new.comment := btrim(coalesce(new.comment,''));
  new.updated_at := now();
  if tg_op = 'INSERT' then
    new.created_by := coalesce(new.created_by, auth.uid());
  end if;
  return new;
end;
$$;

create or replace function private.validate_procurement_request()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_object_name text;
begin
  select o.name into v_object_name
  from public.objects o
  where o.id = new.object_id
    and o.company_id = new.company_id
    and o.is_active = true;
  if v_object_name is null then
    raise exception 'Выбранный объект не найден или отключён';
  end if;
  if new.supplier_id is not null and not exists (
    select 1 from public.procurement_suppliers s
    where s.id = new.supplier_id and s.company_id = new.company_id
  ) then
    raise exception 'Поставщик относится к другой компании';
  end if;
  new.object_name := v_object_name;
  new.title := btrim(new.title);
  new.invoice_number := btrim(coalesce(new.invoice_number,''));
  new.comment := btrim(coalesce(new.comment,''));
  new.updated_at := now();
  if tg_op = 'INSERT' then
    new.requested_by := coalesce(new.requested_by, auth.uid());
  end if;
  return new;
end;
$$;

create or replace function private.validate_procurement_request_item()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1 from public.procurement_requests r
    where r.id = new.request_id and r.company_id = new.company_id
  ) then
    raise exception 'Позиция относится к другой заявке или компании';
  end if;
  new.name := btrim(new.name);
  new.unit := coalesce(nullif(btrim(new.unit),''),'шт.');
  new.note := btrim(coalesce(new.note,''));
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function private.validate_procurement_supplier() from public, anon, authenticated;
revoke all on function private.validate_procurement_request() from public, anon, authenticated;
revoke all on function private.validate_procurement_request_item() from public, anon, authenticated;

drop trigger if exists procurement_suppliers_validate on public.procurement_suppliers;
create trigger procurement_suppliers_validate before insert or update on public.procurement_suppliers
for each row execute function private.validate_procurement_supplier();

drop trigger if exists procurement_requests_validate on public.procurement_requests;
create trigger procurement_requests_validate before insert or update on public.procurement_requests
for each row execute function private.validate_procurement_request();

drop trigger if exists procurement_request_items_validate on public.procurement_request_items;
create trigger procurement_request_items_validate before insert or update on public.procurement_request_items
for each row execute function private.validate_procurement_request_item();

alter table public.procurement_suppliers enable row level security;
alter table public.procurement_requests enable row level security;
alter table public.procurement_request_items enable row level security;

create policy procurement_suppliers_select on public.procurement_suppliers
for select to authenticated
using (company_id = public.current_user_company_id() and public.current_user_has_permission('procurement.suppliers.view'));

create policy procurement_suppliers_insert on public.procurement_suppliers
for insert to authenticated
with check (company_id = public.current_user_company_id() and public.current_user_has_permission('procurement.suppliers.edit'));

create policy procurement_suppliers_update on public.procurement_suppliers
for update to authenticated
using (company_id = public.current_user_company_id() and public.current_user_has_permission('procurement.suppliers.edit'))
with check (company_id = public.current_user_company_id() and public.current_user_has_permission('procurement.suppliers.edit'));

create policy procurement_requests_select on public.procurement_requests
for select to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_has_permission('procurement.requests.view')
  and (public.current_user_role() <> 'foreman' or public.current_user_has_object_scope(object_id))
);

create policy procurement_requests_insert on public.procurement_requests
for insert to authenticated
with check (
  company_id = public.current_user_company_id()
  and public.current_user_has_permission('procurement.requests.create')
  and (public.current_user_role() <> 'foreman' or public.current_user_has_object_scope(object_id))
);

create policy procurement_requests_update on public.procurement_requests
for update to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_has_permission('procurement.requests.edit')
  and (public.current_user_role() <> 'foreman' or public.current_user_has_object_scope(object_id))
)
with check (
  company_id = public.current_user_company_id()
  and public.current_user_has_permission('procurement.requests.edit')
  and (public.current_user_role() <> 'foreman' or public.current_user_has_object_scope(object_id))
);

create policy procurement_items_select on public.procurement_request_items
for select to authenticated
using (exists (
  select 1 from public.procurement_requests r
  where r.id = procurement_request_items.request_id and r.company_id = procurement_request_items.company_id
));

create policy procurement_items_insert on public.procurement_request_items
for insert to authenticated
with check (exists (
  select 1 from public.procurement_requests r
  where r.id = procurement_request_items.request_id and r.company_id = procurement_request_items.company_id
    and public.current_user_has_permission('procurement.requests.edit')
));

create policy procurement_items_update on public.procurement_request_items
for update to authenticated
using (exists (
  select 1 from public.procurement_requests r
  where r.id = procurement_request_items.request_id and r.company_id = procurement_request_items.company_id
    and public.current_user_has_permission('procurement.requests.edit')
))
with check (exists (
  select 1 from public.procurement_requests r
  where r.id = procurement_request_items.request_id and r.company_id = procurement_request_items.company_id
    and public.current_user_has_permission('procurement.requests.edit')
));

create policy procurement_items_delete on public.procurement_request_items
for delete to authenticated
using (exists (
  select 1 from public.procurement_requests r
  where r.id = procurement_request_items.request_id and r.company_id = procurement_request_items.company_id
    and public.current_user_has_permission('procurement.requests.edit')
));

grant select, insert, update on public.procurement_suppliers to authenticated, service_role;
grant select on public.procurement_requests, public.procurement_request_items to authenticated, service_role;
grant insert, update on public.procurement_requests to authenticated, service_role;
grant insert, update, delete on public.procurement_request_items to authenticated, service_role;
