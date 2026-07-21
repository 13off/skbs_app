create or replace function private.validate_company_employer_profile()
returns trigger
language plpgsql
set search_path = public, private
as $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();

  if new.legal_documents_approved
     and (
       btrim(new.legal_name) = ''
       or btrim(new.legal_address) = ''
       or btrim(new.inn) = ''
       or btrim(new.kpp) = ''
       or btrim(new.ogrn) = ''
       or btrim(new.representative_name) = ''
       or btrim(new.representative_position) = ''
       or btrim(new.representative_basis) = ''
       or btrim(new.contract_city) = ''
       or btrim(new.work_schedule) = ''
       or btrim(new.retention_policy) = ''
       or btrim(new.approved_by_name) = ''
       or new.approved_at is null
     ) then
    raise exception 'Employer profile cannot be approved until required legal details are complete';
  end if;

  return new;
end;
$$;

revoke all on function private.validate_company_employer_profile() from public;

drop trigger if exists validate_company_employer_profile_before_write
  on public.company_employer_profiles;
create trigger validate_company_employer_profile_before_write
  before insert or update on public.company_employer_profiles
  for each row execute function private.validate_company_employer_profile();
