from pathlib import Path


def replace(path: str, old: str, new: str, count: int = 1) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    actual = text.count(old)
    if actual < count:
        raise SystemExit(f'{path}: expected at least {count} occurrence(s), found {actual}: {old[:120]!r}')
    text = text.replace(old, new, count)
    p.write_text(text, encoding='utf-8')


# Mobile timesheet: remove the ungrouped state entirely.
replace(
    'lib/screens/timesheet_screen.dart',
    "const String _allTimesheetGroupsFilter = '__all__';\nconst String _ungroupedTimesheetFilter = '__ungrouped__';\n",
    "const String _allTimesheetGroupsFilter = '__all__';\n",
)

replace(
    'lib/screens/timesheet/timesheet_loading.dart',
    "        final filterExists =\n            selectedGroupFilter == _allTimesheetGroupsFilter ||\n            selectedGroupFilter == _ungroupedTimesheetFilter ||\n            groups.any((group) => group.id == selectedGroupFilter);",
    "        final filterExists =\n            selectedGroupFilter == _allTimesheetGroupsFilter ||\n            groups.any((group) => group.id == selectedGroupFilter);",
)

replace(
    'lib/screens/timesheet/timesheet_actions.dart',
    "  bool employeeMatchesGroupFilter(Employee employee) {\n    if (selectedGroupFilter == _allTimesheetGroupsFilter) return true;\n    final group = groupForEmployee(employee);\n    if (selectedGroupFilter == _ungroupedTimesheetFilter) return group == null;\n    return group?.id == selectedGroupFilter;\n  }",
    "  bool employeeMatchesGroupFilter(Employee employee) {\n    if (selectedGroupFilter == _allTimesheetGroupsFilter) return true;\n    return groupForEmployee(employee)?.id == selectedGroupFilter;\n  }",
)

replace(
    'lib/screens/timesheet/timesheet_actions.dart',
    "    if (timesheetGroups.isEmpty) {\n      return <_TimesheetEmployeeGroupSection>[\n        _TimesheetEmployeeGroupSection(title: '', employees: visibleEmployees),\n      ];\n    }",
    "    if (timesheetGroups.isEmpty) {\n      return <_TimesheetEmployeeGroupSection>[\n        _TimesheetEmployeeGroupSection(\n          title: 'Общая',\n          employees: visibleEmployees,\n        ),\n      ];\n    }",
)

old_ungrouped_mobile = """\n    final ungrouped = visibleEmployees\n        .where((employee) => groupForEmployee(employee) == null)\n        .toList(growable: false);\n    if (ungrouped.isNotEmpty &&\n        (selectedGroupFilter == _allTimesheetGroupsFilter ||\n            selectedGroupFilter == _ungroupedTimesheetFilter)) {\n      sections.add(\n        _TimesheetEmployeeGroupSection(\n          title: 'Без группы',\n          employees: ungrouped,\n        ),\n      );\n    }\n"""
replace('lib/screens/timesheet/timesheet_actions.dart', old_ungrouped_mobile, "\n")

replace(
    'lib/screens/timesheet/timesheet_sections.dart',
    "    final currentValue =\n        selectedGroupFilter == _allTimesheetGroupsFilter ||\n            selectedGroupFilter == _ungroupedTimesheetFilter ||\n            groupIds.contains(selectedGroupFilter)\n        ? selectedGroupFilter\n        : _allTimesheetGroupsFilter;",
    "    final currentValue =\n        selectedGroupFilter == _allTimesheetGroupsFilter ||\n            groupIds.contains(selectedGroupFilter)\n        ? selectedGroupFilter\n        : _allTimesheetGroupsFilter;",
)

replace(
    'lib/screens/timesheet/timesheet_sections.dart',
    """                  const DropdownMenuItem<String>(\n                    value: _ungroupedTimesheetFilter,\n                    child: Text('Без группы'),\n                  ),\n""",
    "",
)

# Desktop timesheet: same model, same filter, no hidden ungrouped bucket.
replace(
    'lib/screens/desktop_timesheet_screen.dart',
    "  static const String allGroupsFilter = '__all__';\n  static const String ungroupedFilter = '__ungrouped__';\n",
    "  static const String allGroupsFilter = '__all__';\n",
)
replace(
    'lib/screens/desktop_timesheet_screen.dart',
    "        final filterExists = groupFilter == allGroupsFilter ||\n            groupFilter == ungroupedFilter ||\n            loadedGroups.any((group) => group.id == groupFilter);",
    "        final filterExists = groupFilter == allGroupsFilter ||\n            loadedGroups.any((group) => group.id == groupFilter);",
)
replace(
    'lib/screens/desktop_timesheet_screen.dart',
    "  bool employeeMatchesGroupFilter(Employee employee) {\n    if (groupFilter == allGroupsFilter) return true;\n    final group = groupForEmployee(employee);\n    if (groupFilter == ungroupedFilter) return group == null;\n    return group?.id == groupFilter;\n  }",
    "  bool employeeMatchesGroupFilter(Employee employee) {\n    if (groupFilter == allGroupsFilter) return true;\n    return groupForEmployee(employee)?.id == groupFilter;\n  }",
)
replace(
    'lib/screens/desktop_timesheet_screen.dart',
    "    final validGroupValues = <String>{\n      allGroupsFilter,\n      ungroupedFilter,\n      ...currentGroups.map((group) => group.id),\n    };",
    "    final validGroupValues = <String>{\n      allGroupsFilter,\n      ...currentGroups.map((group) => group.id),\n    };",
)
replace(
    'lib/screens/desktop_timesheet_screen.dart',
    """                      const DropdownMenuItem<String>(\n                        value: ungroupedFilter,\n                        child: Text('Без группы'),\n                      ),\n""",
    "",
)
replace(
    'lib/screens/desktop_timesheet_screen.dart',
    "    if (timesheetGroups.isEmpty) {\n      return visible\n          .map<Widget>(\n            (employee) => _TimesheetRow(\n              employee: employee,\n              value: shiftValueFor(employee),\n              formatShift: formatShift,\n              enabled: !isLoading && !isSaving,\n              onSelected: (value) => setShiftValue(employee, value),\n              onCustom: () => showShiftPicker(employee),\n            ),\n          )\n          .toList(growable: false);\n    }",
    "    if (timesheetGroups.isEmpty) {\n      return <Widget>[\n        _TimesheetGroupTableHeader(title: 'Общая', count: visible.length),\n        ...visible.map<Widget>(\n          (employee) => _TimesheetRow(\n            employee: employee,\n            value: shiftValueFor(employee),\n            formatShift: formatShift,\n            enabled: !isLoading && !isSaving,\n            onSelected: (value) => setShiftValue(employee, value),\n            onCustom: () => showShiftPicker(employee),\n          ),\n        ),\n      ];\n    }",
)
old_ungrouped_desktop = """\n    final ungrouped = visible\n        .where((employee) => groupForEmployee(employee) == null)\n        .toList();\n    if (ungrouped.isNotEmpty &&\n        (groupFilter == allGroupsFilter || groupFilter == ungroupedFilter)) {\n      rows.add(\n        _TimesheetGroupTableHeader(title: 'Без группы', count: ungrouped.length),\n      );\n      rows.addAll(\n        ungrouped.map(\n          (employee) => _TimesheetRow(\n            employee: employee,\n            value: shiftValueFor(employee),\n            formatShift: formatShift,\n            enabled: !isLoading && !isSaving,\n            onSelected: (value) => setShiftValue(employee, value),\n            onCustom: () => showShiftPicker(employee),\n          ),\n        ),\n      );\n    }\n"""
replace('lib/screens/desktop_timesheet_screen.dart', old_ungrouped_desktop, "\n")

# Realtime changes for groups should refresh the employee/group view for foremen too.
replace(
    'lib/data/app_data_sync.dart',
    "      case 'employees':\n      case 'employee_private_data':",
    "      case 'employees':\n      case 'timesheet_groups':\n      case 'timesheet_group_members':\n      case 'employee_private_data':",
)

# Model knows which group is the protected automatic group.
replace(
    'lib/features/timesheet/models/timesheet_group.dart',
    "  final int sortOrder;\n  final Set<String> employeeIds;",
    "  final int sortOrder;\n  final bool isSystem;\n  final Set<String> employeeIds;",
)
replace(
    'lib/features/timesheet/models/timesheet_group.dart',
    "    required this.sortOrder,\n    required this.employeeIds,",
    "    required this.sortOrder,\n    required this.isSystem,\n    required this.employeeIds,",
)
replace(
    'lib/features/timesheet/models/timesheet_group.dart',
    "      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,\n      employeeIds: Set<String>.unmodifiable(employeeIds),",
    "      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,\n      isSystem: map['is_system'] == true,\n      employeeIds: Set<String>.unmodifiable(employeeIds),",
)

# Manager: the automatic group is visible, but it cannot be renamed/deleted.
replace(
    'lib/screens/timesheet_group_manager_sheet.dart',
    "          'Группа «${group.name}» будет удалена. Сотрудники останутся в табеле и попадут в «Без группы».',",
    "          'Группа «${group.name}» будет удалена. Сотрудники автоматически перейдут в группу «Общая».',",
)
replace(
    'lib/screens/timesheet_group_manager_sheet.dart',
    """                                IconButton(\n                                  tooltip: 'Изменить',\n                                  onPressed: loading ? null : () => editGroup(group),\n                                  icon: const Icon(Icons.edit_outlined),\n                                ),\n                                IconButton(\n                                  tooltip: 'Удалить',\n                                  onPressed: loading ? null : () => deleteGroup(group),\n                                  icon: const Icon(Icons.delete_outline_rounded),\n                                ),\n""",
    """                                if (group.isSystem)\n                                  Container(\n                                    padding: const EdgeInsets.symmetric(\n                                      horizontal: 10,\n                                      vertical: 6,\n                                    ),\n                                    decoration: BoxDecoration(\n                                      color: AppAdaptivePalette.accentSoft,\n                                      borderRadius: BorderRadius.circular(999),\n                                    ),\n                                    child: Text(\n                                      'По умолчанию',\n                                      style: TextStyle(\n                                        color: AppAdaptivePalette.textMuted,\n                                        fontSize: 11,\n                                        fontWeight: FontWeight.w800,\n                                      ),\n                                    ),\n                                  )\n                                else ...[\n                                  IconButton(\n                                    tooltip: 'Изменить',\n                                    onPressed: loading\n                                        ? null\n                                        : () => editGroup(group),\n                                    icon: const Icon(Icons.edit_outlined),\n                                  ),\n                                  IconButton(\n                                    tooltip: 'Удалить',\n                                    onPressed: loading\n                                        ? null\n                                        : () => deleteGroup(group),\n                                    icon: const Icon(Icons.delete_outline_rounded),\n                                  ),\n                                ],\n""",
)

# Tests now assert that there is no ungrouped state and the default group is system-managed.
Path('test/timesheet_groups_test.dart').write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/timesheet/models/timesheet_group.dart';

void main() {
  test('timesheet group maps members and system flag', () {
    final group = TimesheetGroup.fromMap(<String, dynamic>{
      'id': 'group-1',
      'object_id': 'object-1',
      'object_name': 'Мурманск',
      'name': 'Общая',
      'sort_order': 1000000,
      'is_system': true,
      'employee_ids': <String>['employee-1', 'employee-2'],
    });

    expect(group.name, 'Общая');
    expect(group.isSystem, isTrue);
    expect(group.employeeIds, containsAll(<String>['employee-1', 'employee-2']));
    expect(group.containsEmployee('employee-1'), isTrue);
    expect(group.containsEmployee('employee-3'), isFalse);
  });

  test('timesheet UI has only real groups and no ungrouped filter', () {
    final mobile = File('lib/screens/timesheet/timesheet_sections.dart')
        .readAsStringSync();
    final mobileState = File('lib/screens/timesheet_screen.dart').readAsStringSync();
    final desktop = File('lib/screens/desktop_timesheet_screen.dart')
        .readAsStringSync();
    final manager = File('lib/screens/timesheet_group_manager_sheet.dart')
        .readAsStringSync();

    expect(mobile, contains("Text('Все группы')"));
    expect(mobile, isNot(contains("Text('Без группы')")));
    expect(mobileState, isNot(contains('_ungroupedTimesheetFilter')));
    expect(desktop, isNot(contains('ungroupedFilter')));
    expect(desktop, isNot(contains("Text('Без группы')")));
    expect(mobile, contains("tooltip: 'Управление группами'"));
    expect(mobile, contains('buildGroupHeader'));
    expect(desktop, contains('_TimesheetGroupTableHeader'));
    expect(manager, contains("'По умолчанию'"));
    expect(manager, contains('group.isSystem'));
    expect(manager, contains("'Создать группу'"));
  });

  test('database gives every active employee a default group', () {
    final migration = File(
      'supabase/migrations/20260820214500_timesheet_groups_always_assigned.sql',
    ).readAsStringSync();

    expect(migration, contains('add column if not exists is_system'));
    expect(migration, contains('ensure_timesheet_default_group'));
    expect(migration, contains("'Общая'"));
    expect(migration, contains('assign_employee_timesheet_group'));
    expect(migration, contains('objects_ensure_timesheet_default_group'));
    expect(migration, contains("raise exception 'Системную группу нельзя удалить'"));
    expect(migration, contains('is_system boolean'));
  });
}
''', encoding='utf-8')

migration = r'''-- Every active employee always belongs to a visible timesheet group.
-- Unassigned employees are kept in one protected system group named «Общая» per object.

alter table public.timesheet_groups
  add column if not exists is_system boolean not null default false;

-- Reuse an existing «Общая» group if an admin happened to create one already.
with candidates as (
  select distinct on (g.company_id, g.object_id)
    g.id
  from public.timesheet_groups g
  where lower(btrim(g.name)) = 'общая'
  order by g.company_id, g.object_id, g.created_at, g.id
)
update public.timesheet_groups g
set is_system = true,
    sort_order = 1000000,
    updated_at = now()
from candidates c
where g.id = c.id
  and not exists (
    select 1
    from public.timesheet_groups existing
    where existing.company_id = g.company_id
      and existing.object_id = g.object_id
      and existing.is_system = true
  );

insert into public.timesheet_groups (
  company_id,
  object_id,
  name,
  sort_order,
  is_system,
  created_by,
  updated_at
)
select
  o.company_id,
  o.id,
  'Общая',
  1000000,
  true,
  null,
  now()
from public.objects o
where o.is_active = true
  and not exists (
    select 1
    from public.timesheet_groups g
    where g.company_id = o.company_id
      and g.object_id = o.id
      and g.is_system = true
  )
  and not exists (
    select 1
    from public.timesheet_groups g
    where g.company_id = o.company_id
      and g.object_id = o.id
      and lower(btrim(g.name)) = 'общая'
  );

create unique index if not exists timesheet_groups_one_system_per_object_uidx
  on public.timesheet_groups(company_id, object_id)
  where is_system = true;

create or replace function private.ensure_timesheet_default_group(
  p_company_id uuid,
  p_object_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_group_id uuid;
begin
  select g.id
    into v_group_id
  from public.timesheet_groups g
  where g.company_id = p_company_id
    and g.object_id = p_object_id
    and g.is_system = true
  limit 1;

  if v_group_id is not null then
    return v_group_id;
  end if;

  select g.id
    into v_group_id
  from public.timesheet_groups g
  where g.company_id = p_company_id
    and g.object_id = p_object_id
    and lower(btrim(g.name)) = 'общая'
  limit 1;

  if v_group_id is not null then
    update public.timesheet_groups
    set is_system = true,
        sort_order = 1000000,
        updated_at = now()
    where id = v_group_id;
    return v_group_id;
  end if;

  begin
    insert into public.timesheet_groups (
      company_id,
      object_id,
      name,
      sort_order,
      is_system,
      created_by,
      updated_at
    ) values (
      p_company_id,
      p_object_id,
      'Общая',
      1000000,
      true,
      null,
      now()
    )
    returning id into v_group_id;
  exception
    when unique_violation then
      select g.id
        into v_group_id
      from public.timesheet_groups g
      where g.company_id = p_company_id
        and g.object_id = p_object_id
        and g.is_system = true
      limit 1;
  end;

  return v_group_id;
end;
$$;

-- Backfill every currently active employee that has no group yet.
insert into public.timesheet_group_members (
  company_id,
  group_id,
  employee_id,
  assigned_by
)
select
  e.company_id,
  g.id,
  e.id,
  null
from public.employees e
join public.timesheet_groups g
  on g.company_id = e.company_id
 and g.object_id = e.object_id
 and g.is_system = true
where e.is_active = true
  and not exists (
    select 1
    from public.timesheet_group_members m
    where m.company_id = e.company_id
      and m.employee_id = e.id
  )
on conflict (company_id, employee_id) do nothing;

create or replace function public.list_timesheet_groups(
  p_object_name text default null
)
returns table (
  id uuid,
  object_id uuid,
  object_name text,
  name text,
  sort_order integer,
  is_system boolean,
  employee_ids uuid[]
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_role text := public.current_user_role();
  v_object_name text := nullif(btrim(p_object_name), '');
begin
  if v_company_id is null or v_role not in ('admin', 'foreman') then
    return;
  end if;

  return query
  select
    g.id,
    g.object_id,
    o.name as object_name,
    g.name,
    g.sort_order,
    g.is_system,
    coalesce(
      array_agg(m.employee_id order by e.fio)
        filter (where m.employee_id is not null),
      '{}'::uuid[]
    ) as employee_ids
  from public.timesheet_groups g
  join public.objects o
    on o.id = g.object_id
   and o.company_id = g.company_id
  left join public.timesheet_group_members m
    on m.group_id = g.id
   and m.company_id = g.company_id
  left join public.employees e
    on e.id = m.employee_id
   and e.company_id = g.company_id
  where g.company_id = v_company_id
    and (v_object_name is null or o.name = v_object_name)
  group by g.id, g.object_id, o.name, g.name, g.sort_order, g.is_system
  order by o.name, g.sort_order, lower(g.name), g.id;
end;
$$;

create or replace function public.save_timesheet_group(
  p_group_id uuid,
  p_object_name text,
  p_name text,
  p_employee_ids uuid[] default '{}'::uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_role text := public.current_user_role();
  v_object_name text := nullif(btrim(p_object_name), '');
  v_name text := nullif(btrim(p_name), '');
  v_object_id uuid;
  v_group_id uuid := p_group_id;
  v_default_group_id uuid;
  v_employee_ids uuid[] := coalesce(p_employee_ids, '{}'::uuid[]);
  v_previous_employee_ids uuid[] := '{}'::uuid[];
  v_next_order integer;
begin
  if v_company_id is null or v_role <> 'admin' then
    raise exception 'Недостаточно прав для управления группами табеля'
      using errcode = '42501';
  end if;
  if v_object_name is null then
    raise exception 'Выберите объект';
  end if;
  if v_name is null then
    raise exception 'Введите название группы';
  end if;
  if char_length(v_name) > 80 then
    raise exception 'Название группы должно быть короче 80 символов';
  end if;

  select o.id
    into v_object_id
  from public.objects o
  where o.company_id = v_company_id
    and o.name = v_object_name
    and o.is_active = true
  limit 1;

  if v_object_id is null then
    raise exception 'Объект не найден';
  end if;

  v_default_group_id := private.ensure_timesheet_default_group(
    v_company_id,
    v_object_id
  );

  if exists (
    select 1
    from unnest(v_employee_ids) as selected(employee_id)
    left join public.employees e on e.id = selected.employee_id
    where e.id is null
       or e.company_id <> v_company_id
       or e.object_id <> v_object_id
       or e.is_active is not true
  ) then
    raise exception 'В группе есть сотрудник другого объекта или неактивный сотрудник';
  end if;

  if v_group_id is null then
    select coalesce(max(g.sort_order) filter (where g.is_system = false), 0) + 10
      into v_next_order
    from public.timesheet_groups g
    where g.company_id = v_company_id
      and g.object_id = v_object_id;

    insert into public.timesheet_groups (
      company_id,
      object_id,
      name,
      sort_order,
      is_system,
      created_by,
      updated_at
    ) values (
      v_company_id,
      v_object_id,
      v_name,
      v_next_order,
      false,
      (select auth.uid()),
      now()
    )
    returning id into v_group_id;
  else
    if exists (
      select 1
      from public.timesheet_groups g
      where g.id = v_group_id
        and g.company_id = v_company_id
        and g.is_system = true
    ) then
      raise exception 'Системную группу нельзя изменять';
    end if;

    if not exists (
      select 1
      from public.timesheet_groups g
      where g.id = v_group_id
        and g.company_id = v_company_id
    ) then
      raise exception 'Группа не найдена';
    end if;

    select coalesce(array_agg(m.employee_id), '{}'::uuid[])
      into v_previous_employee_ids
    from public.timesheet_group_members m
    where m.company_id = v_company_id
      and m.group_id = v_group_id;

    update public.timesheet_groups
    set object_id = v_object_id,
        name = v_name,
        updated_at = now()
    where id = v_group_id
      and company_id = v_company_id;
  end if;

  delete from public.timesheet_group_members
  where group_id = v_group_id
    and company_id = v_company_id;

  if cardinality(v_employee_ids) > 0 then
    delete from public.timesheet_group_members m
    where m.company_id = v_company_id
      and m.employee_id = any(v_employee_ids);

    insert into public.timesheet_group_members (
      company_id,
      group_id,
      employee_id,
      assigned_by
    )
    select
      v_company_id,
      v_group_id,
      selected.employee_id,
      (select auth.uid())
    from unnest(v_employee_ids) as selected(employee_id);
  end if;

  -- Anyone removed from this custom group immediately falls back to «Общая».
  if cardinality(v_previous_employee_ids) > 0 then
    insert into public.timesheet_group_members (
      company_id,
      group_id,
      employee_id,
      assigned_by
    )
    select
      v_company_id,
      v_default_group_id,
      previous.employee_id,
      (select auth.uid())
    from unnest(v_previous_employee_ids) as previous(employee_id)
    join public.employees e
      on e.id = previous.employee_id
     and e.company_id = v_company_id
     and e.object_id = v_object_id
     and e.is_active = true
    where not (previous.employee_id = any(v_employee_ids))
    on conflict (company_id, employee_id) do nothing;
  end if;

  -- Repair any drift so the invariant holds for the whole object.
  insert into public.timesheet_group_members (
    company_id,
    group_id,
    employee_id,
    assigned_by
  )
  select
    e.company_id,
    v_default_group_id,
    e.id,
    (select auth.uid())
  from public.employees e
  where e.company_id = v_company_id
    and e.object_id = v_object_id
    and e.is_active = true
    and not exists (
      select 1
      from public.timesheet_group_members m
      where m.company_id = e.company_id
        and m.employee_id = e.id
    )
  on conflict (company_id, employee_id) do nothing;

  return v_group_id;
exception
  when unique_violation then
    raise exception 'Группа с таким названием уже есть на этом объекте';
end;
$$;

create or replace function public.delete_timesheet_group(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_role text := public.current_user_role();
  v_object_id uuid;
  v_is_system boolean;
  v_default_group_id uuid;
  v_employee_ids uuid[] := '{}'::uuid[];
begin
  if v_company_id is null or v_role <> 'admin' then
    raise exception 'Недостаточно прав для управления группами табеля'
      using errcode = '42501';
  end if;

  select g.object_id, g.is_system
    into v_object_id, v_is_system
  from public.timesheet_groups g
  where g.id = p_group_id
    and g.company_id = v_company_id
  limit 1;

  if v_object_id is null then
    return;
  end if;
  if v_is_system then
    raise exception 'Системную группу нельзя удалить';
  end if;

  select coalesce(array_agg(m.employee_id), '{}'::uuid[])
    into v_employee_ids
  from public.timesheet_group_members m
  where m.company_id = v_company_id
    and m.group_id = p_group_id;

  v_default_group_id := private.ensure_timesheet_default_group(
    v_company_id,
    v_object_id
  );

  delete from public.timesheet_groups
  where id = p_group_id
    and company_id = v_company_id;

  if cardinality(v_employee_ids) > 0 then
    insert into public.timesheet_group_members (
      company_id,
      group_id,
      employee_id,
      assigned_by
    )
    select
      v_company_id,
      v_default_group_id,
      removed.employee_id,
      (select auth.uid())
    from unnest(v_employee_ids) as removed(employee_id)
    join public.employees e
      on e.id = removed.employee_id
     and e.company_id = v_company_id
     and e.object_id = v_object_id
     and e.is_active = true
    on conflict (company_id, employee_id) do nothing;
  end if;
end;
$$;

-- New employees and employees moved between objects are always assigned immediately.
create or replace function private.assign_employee_timesheet_group()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_default_group_id uuid;
begin
  delete from public.timesheet_group_members m
  using public.timesheet_groups g
  where m.group_id = g.id
    and m.employee_id = new.id
    and (
      g.company_id <> new.company_id
      or g.object_id <> new.object_id
      or new.is_active is not true
    );

  if new.is_active is true then
    v_default_group_id := private.ensure_timesheet_default_group(
      new.company_id,
      new.object_id
    );

    insert into public.timesheet_group_members (
      company_id,
      group_id,
      employee_id,
      assigned_by
    ) values (
      new.company_id,
      v_default_group_id,
      new.id,
      (select auth.uid())
    )
    on conflict (company_id, employee_id) do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists employees_cleanup_timesheet_group_members on public.employees;
drop trigger if exists employees_assign_timesheet_group on public.employees;
create trigger employees_assign_timesheet_group
  after insert or update of object_id, company_id, is_active on public.employees
  for each row execute function private.assign_employee_timesheet_group();

create or replace function private.ensure_object_timesheet_default_group()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.is_active is true then
    perform private.ensure_timesheet_default_group(new.company_id, new.id);
  end if;
  return new;
end;
$$;

drop trigger if exists objects_ensure_timesheet_default_group on public.objects;
create trigger objects_ensure_timesheet_default_group
  after insert or update of is_active on public.objects
  for each row execute function private.ensure_object_timesheet_default_group();

revoke all on function public.list_timesheet_groups(text) from public;
revoke all on function public.save_timesheet_group(uuid, text, text, uuid[]) from public;
revoke all on function public.delete_timesheet_group(uuid) from public;
grant execute on function public.list_timesheet_groups(text) to authenticated;
grant execute on function public.save_timesheet_group(uuid, text, text, uuid[]) to authenticated;
grant execute on function public.delete_timesheet_group(uuid) to authenticated;
'''
Path('supabase/migrations/20260820214500_timesheet_groups_always_assigned.sql').write_text(
    migration,
    encoding='utf-8',
)
