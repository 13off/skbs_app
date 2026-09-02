alter table public.recruitment_flights
  add column if not exists segments jsonb not null default '[]'::jsonb;

comment on column public.recruitment_flights.segments is
  'Ordered flight legs for one employee trip; legacy top-level route fields stay populated for backward compatibility.';
