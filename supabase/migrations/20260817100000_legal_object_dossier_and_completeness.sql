-- Полноценное юридическое досье объекта и настраиваемая комплектность сотрудника.

create table if not exists public.legal_object_profiles (
  object_id uuid primary key references public.objects(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  customer_counterparty_id uuid references public.legal_counterparties(id) on delete set null,
  main_contract_document_id uuid references public.legal_documents(id) on delete set null,
  responsible_user_id uuid references auth.users(id) on delete set null,
  contract_value numeric(16,2),
  contract_start date,
  contract_end date,
  notes text not null default '',
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists legal_object_profiles_company_idx
  on public.legal_object_profiles(company_id, object_id);

create or replace function public.guard_legal_object_profile_tenant()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1 from public.objects o
    where o.id = new.object_id and o.company_id = new.company_id
  ) then
    raise exception 'Объект не принадлежит компании';
  end if;
  if new.customer_counterparty_id is not null and not exists (
    select 1 from public.legal_counterparties c
    where c.id = new.customer_counterparty_id and c.company_id = new.company_id
  ) then
    raise exception 'Контрагент не принадлежит компании';
  end if;
  if new.main_contract_document_id is not null and not exists (
    select 1 from public.legal_documents d
    where d.id = new.main_contract_document_id and d.company_id = new.company_id
  ) then
    raise exception 'Договор не принадлежит компании';
  end if;
  new.updated_at := now();
  new.updated_by := coalesce(auth.uid(), new.updated_by);
  if tg_op = 'INSERT' then
    new.created_by := coalesce(auth.uid(), new.created_by);
  end if;
  return new;
end;
$$;

revoke all on function public.guard_legal_object_profile_tenant() from public, anon, authenticated;

drop trigger if exists legal_object_profile_tenant_guard on public.legal_object_profiles;
create trigger legal_object_profile_tenant_guard
before insert or update on public.legal_object_profiles
for each row execute function public.guard_legal_object_profile_tenant();

alter table public.legal_object_profiles enable row level security;
revoke all on public.legal_object_profiles from public, anon;
grant select, insert, update on public.legal_object_profiles to authenticated;

drop policy if exists legal_object_profiles_select on public.legal_object_profiles;
create policy legal_object_profiles_select
on public.legal_object_profiles
for select
to authenticated
using (
  company_id = public.current_user_company_id()
  and (
    public.current_user_has_permission('legal.directory.view')
    or public.is_admin()
  )
);

drop policy if exists legal_object_profiles_insert on public.legal_object_profiles;
create policy legal_object_profiles_insert
on public.legal_object_profiles
for insert
to authenticated
with check (
  company_id = public.current_user_company_id()
  and (
    public.current_user_has_permission('legal.documents.edit')
    or public.current_user_has_permission('legal.matters.edit')
    or public.is_admin()
  )
);

drop policy if exists legal_object_profiles_update on public.legal_object_profiles;
create policy legal_object_profiles_update
on public.legal_object_profiles
for update
to authenticated
using (
  company_id = public.current_user_company_id()
  and (
    public.current_user_has_permission('legal.documents.edit')
    or public.current_user_has_permission('legal.matters.edit')
    or public.is_admin()
  )
)
with check (company_id = public.current_user_company_id());

create or replace function public.legal_object_profile(p_object_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_company uuid := public.current_user_company_id();
  v_result jsonb;
begin
  if auth.uid() is null or v_company is null or not (
    public.current_user_has_permission('legal.directory.view') or public.is_admin()
  ) then
    raise exception 'Нет доступа к досье объекта';
  end if;

  select jsonb_build_object(
    'object_id', o.id,
    'object_name', coalesce(o.name, ''),
    'address', coalesce(o.address, ''),
    'comment', coalesce(o.comment, ''),
    'is_active', coalesce(o.is_active, true),
    'customer_counterparty_id', p.customer_counterparty_id,
    'customer_name', coalesce(c.name, ''),
    'main_contract_document_id', p.main_contract_document_id,
    'main_contract_title', coalesce(d.title, ''),
    'responsible_user_id', p.responsible_user_id,
    'contract_value', p.contract_value,
    'contract_start', p.contract_start,
    'contract_end', p.contract_end,
    'notes', coalesce(p.notes, '')
  ) into v_result
  from public.objects o
  left join public.legal_object_profiles p
    on p.object_id = o.id and p.company_id = o.company_id
  left join public.legal_counterparties c
    on c.id = p.customer_counterparty_id and c.company_id = o.company_id
  left join public.legal_documents d
    on d.id = p.main_contract_document_id and d.company_id = o.company_id
  where o.id = p_object_id and o.company_id = v_company;

  if v_result is null then
    raise exception 'Объект не найден';
  end if;
  return v_result;
end;
$$;

revoke all on function public.legal_object_profile(uuid) from public, anon;
grant execute on function public.legal_object_profile(uuid) to authenticated;

create table if not exists public.legal_document_requirements (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references public.companies(id) on delete cascade,
  code text not null,
  title text not null,
  document_group text not null default 'other',
  matcher_regex text not null,
  is_required boolean not null default true,
  active_only boolean not null default true,
  citizenship_regex text not null default '',
  priority integer not null default 100,
  sort_order integer not null default 100,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists legal_document_requirements_scope_uidx
  on public.legal_document_requirements(coalesce(company_id, '00000000-0000-0000-0000-000000000000'::uuid), code);

alter table public.legal_document_requirements enable row level security;
revoke all on public.legal_document_requirements from public, anon;
grant select, insert, update, delete on public.legal_document_requirements to authenticated;

drop policy if exists legal_document_requirements_select on public.legal_document_requirements;
create policy legal_document_requirements_select
on public.legal_document_requirements
for select
to authenticated
using (
  (company_id is null or company_id = public.current_user_company_id())
  and (
    public.current_user_has_permission('legal.directory.view')
    or public.is_admin()
  )
);

drop policy if exists legal_document_requirements_write on public.legal_document_requirements;
create policy legal_document_requirements_write
on public.legal_document_requirements
for all
to authenticated
using (company_id = public.current_user_company_id() and public.is_admin())
with check (company_id = public.current_user_company_id() and public.is_admin());

insert into public.legal_document_requirements(
  company_id, code, title, document_group, matcher_regex,
  is_required, active_only, priority, sort_order
) values
  (null, 'passport', 'Паспорт', 'personal_document', '(passport|паспорт)', true, true, 10, 10),
  (null, 'registration', 'Регистрация / прописка', 'personal_document', '(registration|пропис|регистрац)', true, true, 20, 20),
  (null, 'snils', 'СНИЛС', 'personal_document', '(snils|снилс)', true, true, 30, 30),
  (null, 'inn', 'ИНН', 'personal_document', '(inn|инн)', true, true, 40, 40),
  (null, 'insurance', 'Полис', 'personal_document', '(polis|полис|insurance|страхов)', true, true, 50, 50),
  (null, 'photo', 'Фото', 'personal_document', '(photo|фото)', true, true, 60, 60),
  (null, 'employee_contract', 'Договор с сотрудником', 'contract', '(гпх|gph|civil|оказан.*услуг|подряд|employment_contract|трудов.*договор|договор|contract)', true, true, 5, 70),
  (null, 'employment_application', 'Заявление на работу', 'application_consent', '(employment_application|заявлен.*работ|заявлен.*при[её]м)', true, true, 15, 80),
  (null, 'salary_transfer_application', 'Заявление о перечислении зарплаты', 'application_consent', '(salary_transfer_application|перечислен.*зарп|получен.*зарп|выплат.*реквиз)', true, true, 15, 90),
  (null, 'personal_data_consent', 'Согласие на обработку персональных данных', 'application_consent', '(personal_data_consent|персональн.*данн|соглас.*обработ)', true, true, 15, 100),
  (null, 'ticket_purchase_agreement', 'Соглашение на приобретение билетов', 'application_consent', '(ticket_purchase_agreement|приобретен.*билет|соглашен.*билет)', false, true, 150, 110),
  (null, 'termination_application', 'Заявление на увольнение', 'application_consent', '(termination_application|заявлен.*увольн)', false, false, 150, 120)
on conflict do nothing;

create or replace function public.legal_employee_completeness(p_employee_id uuid)
returns table(
  requirement_code text,
  requirement_title text,
  document_group text,
  is_required boolean,
  applicable boolean,
  present boolean,
  matched_title text,
  matched_source text,
  priority integer,
  sort_order integer
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_company uuid := public.current_user_company_id();
  v_active boolean;
  v_citizenship text;
begin
  if auth.uid() is null or v_company is null or not (
    public.current_user_has_permission('legal.directory.view')
    or public.current_user_has_permission('legal.documents.view')
    or public.is_admin()
  ) then
    raise exception 'Нет доступа к комплектности документов';
  end if;

  select coalesce(e.is_active, true), coalesce(ra.citizenship, '')
    into v_active, v_citizenship
  from public.employees e
  left join lateral (
    select a.citizenship
    from public.recruitment_applications a
    where a.company_id = e.company_id and a.employee_id = e.id
    order by a.updated_at desc nulls last, a.created_at desc
    limit 1
  ) ra on true
  where e.id = p_employee_id and e.company_id = v_company;

  if not found then
    raise exception 'Сотрудник не найден';
  end if;

  return query
  with req as (
    select distinct on (r.code)
      r.code, r.title, r.document_group, r.matcher_regex, r.is_required,
      r.active_only, r.citizenship_regex, r.priority, r.sort_order,
      (not r.active_only or v_active)
      and (r.citizenship_regex = '' or v_citizenship ~* r.citizenship_regex) as is_applicable
    from public.legal_document_requirements r
    where r.enabled
      and (r.company_id = v_company or r.company_id is null)
    order by r.code, (r.company_id is not null) desc, r.updated_at desc
  ), docs as (
    select d.*,
      lower(
        coalesce(d.title, '') || ' ' ||
        coalesce(d.document_type, '') || ' ' ||
        coalesce(d.file_name, '')
      ) as haystack
    from public.legal_employee_dossier_documents(p_employee_id) d
  )
  select
    r.code,
    r.title,
    r.document_group,
    r.is_required,
    r.is_applicable,
    (m.source_id is not null) as present,
    coalesce(m.title, ''),
    coalesce(m.source_label, ''),
    r.priority,
    r.sort_order
  from req r
  left join lateral (
    select d.source_id, d.title, d.source_label
    from docs d
    where d.haystack ~* r.matcher_regex
    order by d.document_date desc nulls last
    limit 1
  ) m on true
  order by r.sort_order, r.title;
end;
$$;

revoke all on function public.legal_employee_completeness(uuid) from public, anon;
grant execute on function public.legal_employee_completeness(uuid) to authenticated;
