-- Оба индекса обеспечивали одну и ту же уникальность:
-- (company_id, lower(btrim(name))).
-- objects_company_normalized_name_key остаётся действующим.
drop index if exists public.objects_company_name_unique;
