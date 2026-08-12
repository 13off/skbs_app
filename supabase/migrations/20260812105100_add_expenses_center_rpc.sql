create or replace function public.get_expenses_center(
  p_start_date date,
  p_end_date date
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_role text := public.current_user_role();
  v_result jsonb;
begin
  if auth.uid() is null or v_company_id is null or v_role not in ('admin', 'developer', 'accountant') then
    raise exception 'Not allowed';
  end if;

  if p_start_date is null or p_end_date is null or p_start_date > p_end_date then
    raise exception 'Invalid period';
  end if;

  with combined as (
    select
      e.id,
      'manual'::text as source_type,
      e.expense_date,
      e.name,
      e.amount,
      e.category_id,
      coalesce(c.name, 'Без статьи') as category_name,
      e.object_id,
      o.name as object_name,
      e.comment,
      null::text as payment_type,
      true as is_editable,
      e.created_at,
      e.updated_at
    from public.expenses e
    left join public.expense_categories c
      on c.id = e.category_id and c.company_id = v_company_id
    left join public.objects o
      on o.id = e.object_id and o.company_id = v_company_id
    where e.company_id = v_company_id
      and e.expense_date between p_start_date and p_end_date

    union all

    select
      p.id,
      'payment'::text as source_type,
      p.payment_date as expense_date,
      concat('Выплата — ', coalesce(emp.fio, 'Сотрудник')) as name,
      p.amount,
      null::uuid as category_id,
      'Выплаты сотрудникам'::text as category_name,
      p.object_id,
      o.name as object_name,
      coalesce(p.comment, '') as comment,
      p.payment_type,
      false as is_editable,
      p.created_at,
      p.updated_at
    from public.payments p
    left join public.employees emp
      on emp.id = p.employee_id and emp.company_id = v_company_id
    left join public.objects o
      on o.id = p.object_id and o.company_id = v_company_id
    where p.company_id = v_company_id
      and p.deleted_at is null
      and p.payment_date between p_start_date and p_end_date
      and p.amount > 0
  )
  select jsonb_build_object(
    'categories', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id,
        'name', c.name,
        'sort_order', c.sort_order
      ) order by c.sort_order, lower(c.name))
      from public.expense_categories c
      where c.company_id = v_company_id
    ), '[]'::jsonb),
    'objects', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', o.id,
        'name', o.name,
        'is_active', o.is_active
      ) order by case when o.is_active then 0 else 1 end, lower(o.name))
      from public.objects o
      where o.company_id = v_company_id
    ), '[]'::jsonb),
    'rows', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', x.id,
        'source_type', x.source_type,
        'expense_date', x.expense_date,
        'name', x.name,
        'amount', x.amount,
        'category_id', x.category_id,
        'category_name', x.category_name,
        'object_id', x.object_id,
        'object_name', x.object_name,
        'comment', x.comment,
        'payment_type', x.payment_type,
        'is_editable', x.is_editable,
        'created_at', x.created_at,
        'updated_at', x.updated_at
      ) order by x.expense_date desc, x.created_at desc)
      from combined x
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.get_expenses_center(date, date) from public;
grant execute on function public.get_expenses_center(date, date) to authenticated;

comment on function public.get_expenses_center(date, date) is 'Единая выдача ручных расходов и неудалённых выплат за период для текущей компании.';
