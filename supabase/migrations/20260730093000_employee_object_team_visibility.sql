alter table public.employee_professional_profiles
  add column if not exists visibility_scope text not null default 'object';

do $$
begin
  alter table public.employee_professional_profiles
    add constraint employee_professional_profiles_visibility_scope_check
    check (visibility_scope in ('private', 'object', 'company', 'employers'));
exception
  when duplicate_object then null;
end
$$;

comment on column public.employee_professional_profiles.visibility_scope is
  'Видимость расширенной профессиональной части: private, object, company или employers. Базовые рабочие сведения остаются доступны коллегам текущего объекта.';

create index if not exists employee_professional_profiles_visibility_idx
  on public.employee_professional_profiles (company_id, visibility_scope);
