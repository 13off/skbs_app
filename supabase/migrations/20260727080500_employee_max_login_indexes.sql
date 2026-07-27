create index if not exists employee_max_links_person_idx
  on public.employee_max_links (person_id);

create index if not exists employee_max_links_user_idx
  on public.employee_max_links (user_id);

create index if not exists employee_max_link_tokens_person_idx
  on public.employee_max_link_tokens (person_id);

create index if not exists employee_max_link_tokens_user_idx
  on public.employee_max_link_tokens (user_id);

create index if not exists employee_max_link_tokens_created_by_idx
  on public.employee_max_link_tokens (created_by)
  where created_by is not null;
