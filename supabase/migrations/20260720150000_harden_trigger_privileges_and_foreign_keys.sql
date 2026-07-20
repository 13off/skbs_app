-- Trigger-функции вызываются только самим PostgreSQL и не должны быть RPC.
revoke all on function private.audit_developer_constructor_item()
  from public, anon, authenticated;
revoke all on function private.audit_dispatcher_summary_settings()
  from public, anon, authenticated;
revoke all on function private.validate_developer_custom_setting()
  from public, anon, authenticated;
revoke all on function private.validate_developer_reminder_rule()
  from public, anon, authenticated;
revoke all on function private.validate_dispatcher_summary_settings()
  from public, anon, authenticated;
revoke all on function public.touch_updated_at()
  from public, anon, authenticated;

-- Создаём обычные покрывающие индексы для внешних ключей, у которых нет
-- полного непредикатного индекса с теми же начальными колонками. Это ускоряет
-- проверки UPDATE/DELETE родительских записей и каскадные операции.
do $$
declare
  r record;
  v_index_name text;
begin
  for r in
    with foreign_keys as (
      select
        con.oid as constraint_oid,
        con.conrelid,
        n.nspname as schema_name,
        c.relname as table_name,
        con.conname as constraint_name,
        con.conkey,
        string_agg(format('%I', a.attname), ', ' order by u.ordinality)
          as quoted_columns,
        string_agg(a.attname, '_' order by u.ordinality)
          as name_columns
      from pg_constraint con
      join pg_class c on c.oid = con.conrelid
      join pg_namespace n on n.oid = c.relnamespace
      cross join lateral unnest(con.conkey)
        with ordinality u(attnum, ordinality)
      join pg_attribute a
        on a.attrelid = c.oid
       and a.attnum = u.attnum
      where con.contype = 'f'
        and n.nspname = 'public'
      group by
        con.oid,
        con.conrelid,
        n.nspname,
        c.relname,
        con.conname,
        con.conkey
    )
    select fk.*
    from foreign_keys fk
    where not exists (
      select 1
      from pg_index i
      where i.indrelid = fk.conrelid
        and i.indisvalid
        and i.indisready
        and i.indpred is null
        and (i.indkey::smallint[])[0:cardinality(fk.conkey) - 1]
          = fk.conkey
    )
    order by fk.table_name, fk.constraint_name
  loop
    v_index_name := left(
      r.table_name || '_' || r.name_columns || '_fk_',
      48
    ) || substr(md5(r.constraint_name), 1, 8) || '_idx';

    execute format(
      'create index if not exists %I on %I.%I (%s)',
      v_index_name,
      r.schema_name,
      r.table_name,
      r.quoted_columns
    );
  end loop;
end;
$$;
