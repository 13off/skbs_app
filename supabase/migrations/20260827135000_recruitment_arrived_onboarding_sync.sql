-- Keep the legacy recruitment status in sync with the custom HR stage
-- "Прилетел" so the existing onboarding panel can consume that stage.
--
-- The recruitment board is stage-driven, while the onboarding queue still
-- reads the legacy status. Custom pipelines may intentionally keep
-- legacy_status = 'new' for all stages, so moving a candidate to "Прилетел"
-- previously did not make the candidate visible in "Оформление".

create or replace function public.sync_recruitment_arrived_onboarding_status()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_new_stage_title text := '';
  v_old_stage_title text := '';
  v_new_legacy_status text := '';
begin
  if new.stage_id is not null then
    select
      lower(trim(coalesce(stage.title, ''))),
      trim(coalesce(stage.legacy_status, ''))
    into v_new_stage_title, v_new_legacy_status
    from public.recruitment_pipeline_stages stage
    where stage.id = new.stage_id
      and stage.company_id = new.company_id;
  end if;

  if tg_op = 'UPDATE' and old.stage_id is not null then
    select lower(trim(coalesce(stage.title, '')))
    into v_old_stage_title
    from public.recruitment_pipeline_stages stage
    where stage.id = old.stage_id
      and stage.company_id = old.company_id;
  end if;

  -- Entering the exact HR stage "Прилетел" puts an unlinked candidate into
  -- the onboarding queue consumed by HR -> "Оформление".
  if v_new_stage_title = 'прилетел' and new.employee_id is null then
    new.status := 'arrived';
    return new;
  end if;

  -- If an unlinked candidate is moved back out of "Прилетел", remove the
  -- onboarding marker again. Linked employees keep their hired status.
  if tg_op = 'UPDATE'
     and v_old_stage_title = 'прилетел'
     and v_new_stage_title <> 'прилетел'
     and new.employee_id is null then
    new.status := case
      when v_new_legacy_status <> '' then v_new_legacy_status
      else 'new'
    end;
  end if;

  return new;
end;
$$;

drop trigger if exists recruitment_arrived_onboarding_status_sync
on public.recruitment_applications;

create trigger recruitment_arrived_onboarding_status_sync
before insert or update of stage_id
on public.recruitment_applications
for each row
execute function public.sync_recruitment_arrived_onboarding_status();

-- Backfill candidates that are already sitting in "Прилетел" at deployment
-- time. Do not touch candidates that have already been linked to employees.
update public.recruitment_applications application
set status = 'arrived',
    updated_at = now()
from public.recruitment_pipeline_stages stage
where application.stage_id = stage.id
  and application.company_id = stage.company_id
  and lower(trim(coalesce(stage.title, ''))) = 'прилетел'
  and application.archived_at is null
  and application.employee_id is null
  and application.status is distinct from 'arrived';
