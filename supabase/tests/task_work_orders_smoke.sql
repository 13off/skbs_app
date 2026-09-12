-- Transactional verification on an existing workspace; no business data survives.
begin;
do $$
declare
  account record; chosen_task uuid; chosen_employee uuid; foreign_task uuid;
  checked integer := 0; checked_foremen integer := 0; denied_task uuid; participants jsonb;
begin
  if has_table_privilege('anon','public.task_work_days','select') then
    raise exception 'Anonymous access granted';
  end if;
  for account in
    select p.id, m.role from public.user_profiles p
      join public.company_memberships m on m.user_id=p.id and m.company_id=p.active_company_id
    where p.is_active and m.is_active and m.role in ('admin','owner','foreman')
  loop
    perform set_config('request.jwt.claim.sub',account.id::text,true);
    chosen_task := null;
    select t.id,a.employee_id into chosen_task,chosen_employee
      from public.tasks t join public.task_assignees a on a.task_id=t.id
      where public.task_is_allowed_for_user(t.id)
      and not exists(select 1 from public.task_work_plans p where p.task_id=t.id)
      limit 1;
    if chosen_task is null then continue; end if;
    select id into foreign_task from public.tasks
      where company_id <> public.current_user_company_id() limit 1;
    select id into denied_task from public.tasks
      where company_id = public.current_user_company_id() and not public.task_is_allowed_for_user(id) limit 1;
    participants := jsonb_build_array(jsonb_build_object('employee_id',chosen_employee,'ktu',100,'fio','FORGED'));
    set local role authenticated;
    perform public.save_task_work_day(chosen_task,100,'м³','2026-09-10',25,participants);
    if not exists(select 1 from public.task_work_days where task_id=chosen_task
        and quantity=25 and task_work_days.participants->0->>'fio' <> 'FORGED') then
      raise exception 'Daily output or canonical name missing for %',account.role;
    end if;
    perform public.save_task_work_day(chosen_task,100,'м³','2026-09-10',50,participants);
    if (select quantity from public.task_work_days where task_id=chosen_task and work_date='2026-09-10') <> 50 then
      raise exception 'Daily replacement failed';
    end if;
    begin
      perform public.save_task_work_day(chosen_task,100,'м³','2026-09-11',-1,participants);
      raise exception 'Negative quantity accepted';
    exception when check_violation then null;
    end;
    begin
      perform public.save_task_work_day(chosen_task,100,'м³','2026-09-11',10,
          jsonb_build_array(jsonb_build_object('employee_id',chosen_employee,'ktu',0)));
      raise exception 'Zero KTU accepted';
    exception when raise_exception then
      if sqlerrm = 'Zero KTU accepted' then raise; end if;
    end;
    begin
      perform public.save_task_work_day(chosen_task,100,'м³','2026-09-11',10,
          jsonb_build_array(jsonb_build_object('employee_id',chosen_employee,'ktu',201)));
      raise exception 'KTU above 200 accepted';
    exception when raise_exception then
      if sqlerrm = 'KTU above 200 accepted' then raise; end if;
    end;
    perform public.save_task_work_day(chosen_task,100,'м³','2026-09-11',10,
        jsonb_build_array(jsonb_build_object('employee_id',chosen_employee,'ktu',200)));
    if foreign_task is not null then
      begin
        perform public.save_task_work_day(foreign_task,100,'м³','2026-09-10',25,participants);
        raise exception 'Cross-company write accepted';
      exception when insufficient_privilege then null;
      end;
    end if;
    if denied_task is not null then
      begin
        perform public.save_task_work_day(denied_task,100,'м³','2026-09-10',25,participants);
        raise exception 'Out-of-scope task write accepted';
      exception when insufficient_privilege then null;
      end;
    end if;
    if account.role = 'foreman' then checked_foremen := checked_foremen + 1; end if;
    delete from public.task_work_days where task_id=chosen_task;
    delete from public.task_work_plans where task_id=chosen_task;
    reset role;
    checked := checked + 1;
  end loop;
  if checked_foremen = 0 then raise exception 'No foreman fixture verified'; end if;
  if checked = 0 then raise exception 'No eligible task fixture'; end if;
  raise notice 'Work order role fixtures verified: %',checked;
end;
$$;
rollback;
