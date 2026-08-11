-- Multiple ticket attachments for one recruitment flight.
-- Keeps the original ticket_* columns on recruitment_flights as the legacy/primary ticket
-- so existing clients, reminders and voice flows remain backward compatible.

create table if not exists public.recruitment_flight_tickets (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  flight_id uuid not null references public.recruitment_flights(id) on delete cascade,
  bucket text not null default 'recruitment-documents',
  path text not null,
  original_name text not null,
  mime_type text not null default 'application/pdf',
  size_bytes bigint,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint recruitment_flight_tickets_file_check check (
    char_length(btrim(bucket)) > 0
    and char_length(btrim(path)) > 0
    and char_length(btrim(original_name)) > 0
  ),
  constraint recruitment_flight_tickets_size_check check (
    size_bytes is null or (size_bytes > 0 and size_bytes <= 20971520)
  ),
  constraint recruitment_flight_tickets_company_path_unique unique (company_id, path)
);

create index if not exists recruitment_flight_tickets_flight_idx
  on public.recruitment_flight_tickets(company_id, flight_id, created_at, id);

-- Backfill every old single-ticket flight as its first attachment.
insert into public.recruitment_flight_tickets(
  company_id,
  flight_id,
  bucket,
  path,
  original_name,
  mime_type,
  size_bytes,
  created_by,
  created_at
)
select
  flight.company_id,
  flight.id,
  flight.ticket_bucket,
  flight.ticket_path,
  flight.ticket_original_name,
  flight.ticket_mime_type,
  flight.ticket_size_bytes,
  flight.created_by,
  flight.created_at
from public.recruitment_flights flight
where char_length(btrim(flight.ticket_path)) > 0
on conflict (company_id, path) do nothing;

alter table public.recruitment_flight_tickets enable row level security;
revoke all on table public.recruitment_flight_tickets from public, anon;
grant select, insert, delete on table public.recruitment_flight_tickets to authenticated;

create policy recruitment_flight_tickets_select on public.recruitment_flight_tickets
  for select to authenticated using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.applications.view')
    and exists (
      select 1
      from public.recruitment_flights flight
      where flight.id = recruitment_flight_tickets.flight_id
        and flight.company_id = recruitment_flight_tickets.company_id
    )
  );

create policy recruitment_flight_tickets_insert on public.recruitment_flight_tickets
  for insert to authenticated with check (
    company_id = (select public.current_user_company_id())
    and created_by = (select auth.uid())
    and public.current_user_has_permission('recruitment.applications.edit')
    and exists (
      select 1
      from public.recruitment_flights flight
      where flight.id = recruitment_flight_tickets.flight_id
        and flight.company_id = recruitment_flight_tickets.company_id
    )
  );

create policy recruitment_flight_tickets_delete on public.recruitment_flight_tickets
  for delete to authenticated using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.applications.edit')
    and exists (
      select 1
      from public.recruitment_flights flight
      where flight.id = recruitment_flight_tickets.flight_id
        and flight.company_id = recruitment_flight_tickets.company_id
    )
  );
