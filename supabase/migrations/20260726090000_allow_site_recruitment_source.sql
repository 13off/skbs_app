alter table public.recruitment_applications
  drop constraint if exists recruitment_applications_source_check;

alter table public.recruitment_applications
  add constraint recruitment_applications_source_check
  check (
    source = any (
      array[
        'manual'::text,
        'telegram'::text,
        'max'::text,
        'site'::text
      ]
    )
  );
