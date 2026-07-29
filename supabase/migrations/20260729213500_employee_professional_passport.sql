create table if not exists public.employee_professional_profiles (
  company_id uuid not null references public.companies(id) on delete cascade,
  person_id uuid not null references private.people(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  grade text not null default '',
  experience_years numeric(4, 1) not null default 0
    check (experience_years >= 0 and experience_years <= 70),
  skills text[] not null default '{}'::text[]
    check (cardinality(skills) <= 20),
  about text not null default '',
  preferred_cities text[] not null default '{}'::text[]
    check (cardinality(preferred_cities) <= 12),
  ready_for_rotation boolean not null default false,
  open_to_offers boolean not null default false,
  desired_daily_rate integer
    check (desired_daily_rate is null or desired_daily_rate between 0 and 10000000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (company_id, person_id),
  unique (company_id, user_id)
);

comment on table public.employee_professional_profiles is
  'Личная профессиональная часть паспорта строителя. Подтверждённые показатели рассчитываются отдельно по рабочим данным AppСтрой.';
comment on column public.employee_professional_profiles.open_to_offers is
  'Готовность сотрудника получать предложения. Само по себе поле не делает профиль публичным.';

create index if not exists employee_professional_profiles_user_idx
  on public.employee_professional_profiles (user_id, company_id);
create index if not exists employee_professional_profiles_offers_idx
  on public.employee_professional_profiles (company_id, open_to_offers)
  where open_to_offers = true;

alter table public.employee_professional_profiles enable row level security;
revoke all on table public.employee_professional_profiles from anon, authenticated;
grant all on table public.employee_professional_profiles to service_role;

create or replace function public.employee_professional_summary(
  p_company_id uuid,
  p_person_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = public, private, pg_temp
as $$
  with employee_rows as (
    select e.id, nullif(btrim(e.object_name), '') as object_name
    from public.employees e
    where e.company_id = p_company_id
      and e.person_id = p_person_id
      and e.archived_at is null
  ),
  attendance_summary as (
    select
      coalesce(sum(a.shifts), 0)::numeric as total_shifts,
      coalesce(sum(a.hours), 0)::numeric as total_hours,
      min(a.work_date) as first_work_date
    from public.attendance a
    where a.employee_id in (select id from employee_rows)
      and a.company_id = p_company_id
      and a.deleted_at is null
  ),
  task_summary as (
    select count(distinct t.id)::integer as completed_tasks
    from public.task_assignees ta
    join public.tasks t on t.id = ta.task_id
    where ta.employee_id in (select id from employee_rows)
      and ta.company_id = p_company_id
      and t.company_id = p_company_id
      and t.deleted_at is null
      and t.status = 'Выполнено'
  ),
  object_summary as (
    select coalesce(jsonb_agg(object_name order by object_name), '[]'::jsonb) as object_names
    from (
      select distinct object_name
      from employee_rows
      where object_name is not null
    ) objects
  ),
  document_summary as (
    select (
      select count(*)
      from public.recruitment_onboarding_forms f
      where f.company_id = p_company_id
        and f.employee_id in (select id from employee_rows)
    ) + (
      select count(*)
      from public.legal_documents d
      where d.company_id = p_company_id
        and d.employee_id in (select id from employee_rows)
        and d.archived_at is null
    ) as documents
  )
  select jsonb_build_object(
    'total_shifts', attendance_summary.total_shifts,
    'total_hours', attendance_summary.total_hours,
    'first_work_date', attendance_summary.first_work_date,
    'completed_tasks', task_summary.completed_tasks,
    'object_names', object_summary.object_names,
    'documents', document_summary.documents
  )
  from attendance_summary, task_summary, object_summary, document_summary;
$$;

revoke all on function public.employee_professional_summary(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.employee_professional_summary(uuid, uuid)
  to service_role;
