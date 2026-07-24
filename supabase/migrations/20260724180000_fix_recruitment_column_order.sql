begin;

create or replace function public.create_recruitment_pipeline_stage_at_end(
  p_title text,
  p_description text default '',
  p_color_hex text default '#2F80ED',
  p_legacy_status text default 'new',
  p_is_final boolean default false
)
returns jsonb
language plpgsql
set search_path to ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_user_id uuid := (select auth.uid());
  v_title text := left(btrim(coalesce(p_title, '')), 160);
  v_color_hex text := upper(btrim(coalesce(p_color_hex, '#2F80ED')));
  v_sort_order integer;
  v_result jsonb;
begin
  if v_user_id is null or v_company_id is null then
    raise exception 'Требуется авторизация';
  end if;
  if not public.current_user_has_permission('recruitment.crm.configure') then
    raise exception 'Недостаточно прав для настройки CRM';
  end if;
  if v_title = '' then
    raise exception 'Введите название колонки';
  end if;
  if v_color_hex !~ '^#[0-9A-F]{6}$' then
    v_color_hex := '#2F80ED';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_company_id::text, 0));
  select coalesce(max(stage.sort_order), 0) + 10
    into v_sort_order
  from public.recruitment_pipeline_stages stage
  where stage.company_id = v_company_id
    and stage.is_active;

  insert into public.recruitment_pipeline_stages as stage(
    company_id,
    title,
    description,
    color_hex,
    sort_order,
    legacy_status,
    is_final,
    is_active,
    created_by
  ) values (
    v_company_id,
    v_title,
    btrim(coalesce(p_description, '')),
    v_color_hex,
    v_sort_order,
    coalesce(nullif(btrim(p_legacy_status), ''), 'new'),
    coalesce(p_is_final, false),
    true,
    v_user_id
  )
  returning to_jsonb(stage) into v_result;

  return v_result;
end;
$$;

create or replace function public.reorder_recruitment_pipeline_stages_v2(
  p_stage_ids uuid[]
)
returns jsonb
language plpgsql
set search_path to ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
begin
  perform public.reorder_recruitment_pipeline_stages(p_stage_ids);
  return (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
'id', stage.id,
'sort_order', stage.sort_order
        )
        order by stage.sort_order, stage.created_at, stage.id
      ),
      '[]'::jsonb
    )
    from public.recruitment_pipeline_stages stage
    where stage.company_id = v_company_id
      and stage.is_active
  );
end;
$$;

revoke all on function public.create_recruitment_pipeline_stage_at_end(text, text, text, text, boolean) from public;
revoke all on function public.create_recruitment_pipeline_stage_at_end(text, text, text, text, boolean) from anon;
grant execute on function public.create_recruitment_pipeline_stage_at_end(text, text, text, text, boolean) to authenticated;

revoke all on function public.reorder_recruitment_pipeline_stages(uuid[]) from public;
revoke all on function public.reorder_recruitment_pipeline_stages(uuid[]) from anon;
grant execute on function public.reorder_recruitment_pipeline_stages(uuid[]) to authenticated;

revoke all on function public.reorder_recruitment_pipeline_stages_v2(uuid[]) from public;
revoke all on function public.reorder_recruitment_pipeline_stages_v2(uuid[]) from anon;
grant execute on function public.reorder_recruitment_pipeline_stages_v2(uuid[]) to authenticated;

commit;
