from pathlib import Path
import re


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'Expected block not found in {path}: {old[:120]!r}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


def regex_once(path: str, pattern: str, replacement: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    next_text, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f'Expected regex once in {path}, got {count}: {pattern[:120]!r}')
    p.write_text(next_text, encoding='utf-8')


Path('lib/features/timesheet/models/timesheet_group.dart').write_text(r'''class TimesheetGroup {
  final String id;
  final String objectId;
  final String objectName;
  final String name;
  final int sortOrder;
  final Set<String> employeeIds;

  const TimesheetGroup({
    required this.id,
    required this.objectId,
    required this.objectName,
    required this.name,
    required this.sortOrder,
    required this.employeeIds,
  });

  bool containsEmployee(String? employeeId) {
    return employeeId != null && employeeIds.contains(employeeId);
  }

  factory TimesheetGroup.fromMap(Map<String, dynamic> map) {
    final rawEmployeeIds = map['employee_ids'];
    final employeeIds = rawEmployeeIds is List
        ? rawEmployeeIds
              .map((value) => value?.toString().trim() ?? '')
              .where((value) => value.isNotEmpty)
              .toSet()
        : <String>{};

    return TimesheetGroup(
      id: map['id']?.toString() ?? '',
      objectId: map['object_id']?.toString() ?? '',
      objectName: map['object_name']?.toString().trim() ?? '',
      name: map['name']?.toString().trim() ?? '',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      employeeIds: Set<String>.unmodifiable(employeeIds),
    );
  }
}
''', encoding='utf-8')

Path('lib/features/timesheet/data/timesheet_group_repository.dart').write_text(r'''import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/app_data_sync.dart';
import '../models/timesheet_group.dart';

class TimesheetGroupRepository {
  TimesheetGroupRepository._();

  static final SupabaseClient _client = Supabase.instance.client;

  static String? _cleanObjectName(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  static List<TimesheetGroup> _sortGroups(Iterable<TimesheetGroup> groups) {
    final result = groups.toList(growable: false);
    result.sort((first, second) {
      final objectCompare = first.objectName.compareTo(second.objectName);
      if (objectCompare != 0) return objectCompare;
      final orderCompare = first.sortOrder.compareTo(second.sortOrder);
      if (orderCompare != 0) return orderCompare;
      return first.name.toLowerCase().compareTo(second.name.toLowerCase());
    });
    return result;
  }

  static Future<List<TimesheetGroup>> fetchGroups({String? objectName}) async {
    final result = await _client.rpc(
      'list_timesheet_groups',
      params: <String, dynamic>{'p_object_name': _cleanObjectName(objectName)},
    );

    if (result is! List) return const <TimesheetGroup>[];
    return _sortGroups(
      result.whereType<Map>().map(
        (row) => TimesheetGroup.fromMap(Map<String, dynamic>.from(row)),
      ),
    );
  }

  static Future<String> saveGroup({
    String? groupId,
    required String objectName,
    required String name,
    required Iterable<String> employeeIds,
  }) async {
    final cleanObject = _cleanObjectName(objectName);
    final cleanName = name.trim();
    if (cleanObject == null) throw Exception('Выберите объект');
    if (cleanName.isEmpty) throw Exception('Введите название группы');
    if (cleanName.length > 80) {
      throw Exception('Название группы должно быть короче 80 символов');
    }

    final cleanIds = employeeIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final result = await _client.rpc(
      'save_timesheet_group',
      params: <String, dynamic>{
        'p_group_id': groupId?.trim().isEmpty == false ? groupId!.trim() : null,
        'p_object_name': cleanObject,
        'p_name': cleanName,
        'p_employee_ids': cleanIds,
      },
    );

    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.timesheetGroups},
      context: <String, dynamic>{
        'table': 'timesheet_groups',
        'object_name': cleanObject,
      },
    );
    return result?.toString() ?? '';
  }

  static Future<void> deleteGroup(String groupId) async {
    final cleanId = groupId.trim();
    if (cleanId.isEmpty) return;
    await _client.rpc(
      'delete_timesheet_group',
      params: <String, dynamic>{'p_group_id': cleanId},
    );
    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.timesheetGroups},
      context: const <String, dynamic>{'table': 'timesheet_groups'},
    );
  }
}
''', encoding='utf-8')

Path('lib/screens/timesheet_group_manager_sheet.dart').write_text(r'''import 'package:flutter/material.dart';

import '../app/app_adaptive_palette.dart';
import '../features/timesheet/data/timesheet_group_repository.dart';
import '../features/timesheet/models/timesheet_group.dart';
import '../models/employee.dart';
import '../widgets/premium_ui.dart';

class TimesheetGroupManagerSheet extends StatefulWidget {
  final String? selectedObjectName;
  final List<Employee> employees;
  final List<TimesheetGroup> initialGroups;

  const TimesheetGroupManagerSheet({
    super.key,
    required this.selectedObjectName,
    required this.employees,
    required this.initialGroups,
  });

  static Future<bool> show(
    BuildContext context, {
    required String? selectedObjectName,
    required List<Employee> employees,
    required List<TimesheetGroup> groups,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TimesheetGroupManagerSheet(
        selectedObjectName: selectedObjectName,
        employees: employees,
        initialGroups: groups,
      ),
    );
    return result == true;
  }

  @override
  State<TimesheetGroupManagerSheet> createState() =>
      _TimesheetGroupManagerSheetState();
}

class _TimesheetGroupManagerSheetState
    extends State<TimesheetGroupManagerSheet> {
  late List<TimesheetGroup> groups;
  bool loading = false;
  bool changed = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    groups = List<TimesheetGroup>.from(widget.initialGroups);
  }

  String? cleanObjectName(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  List<String> get objectOptions {
    final values = <String>{
      if (cleanObjectName(widget.selectedObjectName) case final value?) value,
      ...widget.employees
          .map((employee) => employee.objectName.trim())
          .where((value) => value.isNotEmpty),
    }.toList()
      ..sort();
    return values;
  }

  Future<void> reload() async {
    setState(() {
      loading = true;
      errorText = null;
    });
    try {
      final result = await TimesheetGroupRepository.fetchGroups(
        objectName: widget.selectedObjectName,
      );
      if (!mounted) return;
      setState(() => groups = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => errorText = 'Не удалось обновить группы: $error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> editGroup([TimesheetGroup? group]) async {
    final draft = await showDialog<_TimesheetGroupDraft>(
      context: context,
      builder: (context) => _TimesheetGroupEditorDialog(
        group: group,
        lockedObjectName: cleanObjectName(widget.selectedObjectName),
        objectOptions: objectOptions,
        employees: widget.employees,
        allGroups: groups,
      ),
    );
    if (draft == null || !mounted) return;

    setState(() {
      loading = true;
      errorText = null;
    });
    try {
      await TimesheetGroupRepository.saveGroup(
        groupId: group?.id,
        objectName: draft.objectName,
        name: draft.name,
        employeeIds: draft.employeeIds,
      );
      changed = true;
      await reload();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = 'Не удалось сохранить группу: $error';
      });
    }
  }

  Future<void> deleteGroup(TimesheetGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить группу?'),
        content: Text(
          'Группа «${group.name}» будет удалена. Сотрудники останутся в табеле и попадут в «Без группы».',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      loading = true;
      errorText = null;
    });
    try {
      await TimesheetGroupRepository.deleteGroup(group.id);
      changed = true;
      await reload();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = 'Не удалось удалить группу: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: FractionallySizedBox(
          heightFactor: 0.92,
          child: Material(
            color: AppAdaptivePalette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Группы табеля',
                              style: TextStyle(
                                color: AppAdaptivePalette.textPrimary,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Руководитель распределяет сотрудников, прораб использует группы при заполнении.',
                              style: TextStyle(
                                color: AppAdaptivePalette.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Закрыть',
                        onPressed: () => Navigator.pop(context, changed),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppAdaptivePalette.border),
                if (loading) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      if (errorText != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppAdaptivePalette.warning.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            errorText!,
                            style: TextStyle(
                              color: AppAdaptivePalette.warning,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (groups.isEmpty)
                        PremiumWorkCard(
                          radius: 22,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(
                                Icons.groups_2_outlined,
                                size: 34,
                                color: AppAdaptivePalette.textMuted,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Групп пока нет',
                                style: TextStyle(
                                  color: AppAdaptivePalette.textPrimary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Например: «Бетонщики», «Отделочники», «Киргизы».',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppAdaptivePalette.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...groups.map(
                          (group) => PremiumWorkCard(
                            margin: const EdgeInsets.only(bottom: 10),
                            radius: 20,
                            padding: const EdgeInsets.fromLTRB(15, 12, 8, 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: AppAdaptivePalette.accentSoft,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.groups_2_outlined,
                                    color: AppAdaptivePalette.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        group.name,
                                        style: TextStyle(
                                          color: AppAdaptivePalette.textPrimary,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${group.objectName} · ${group.employeeIds.length} чел.',
                                        style: TextStyle(
                                          color: AppAdaptivePalette.textMuted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Изменить',
                                  onPressed: loading ? null : () => editGroup(group),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Удалить',
                                  onPressed: loading ? null : () => deleteGroup(group),
                                  icon: const Icon(Icons.delete_outline_rounded),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: loading || objectOptions.isEmpty
                          ? null
                          : () => editGroup(),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Создать группу'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimesheetGroupDraft {
  final String objectName;
  final String name;
  final Set<String> employeeIds;

  const _TimesheetGroupDraft({
    required this.objectName,
    required this.name,
    required this.employeeIds,
  });
}

class _TimesheetGroupEditorDialog extends StatefulWidget {
  final TimesheetGroup? group;
  final String? lockedObjectName;
  final List<String> objectOptions;
  final List<Employee> employees;
  final List<TimesheetGroup> allGroups;

  const _TimesheetGroupEditorDialog({
    required this.group,
    required this.lockedObjectName,
    required this.objectOptions,
    required this.employees,
    required this.allGroups,
  });

  @override
  State<_TimesheetGroupEditorDialog> createState() =>
      _TimesheetGroupEditorDialogState();
}

class _TimesheetGroupEditorDialogState
    extends State<_TimesheetGroupEditorDialog> {
  late final TextEditingController nameController;
  final TextEditingController searchController = TextEditingController();
  late String objectName;
  late Set<String> selectedEmployeeIds;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.group?.name ?? '');
    objectName = widget.group?.objectName ??
        widget.lockedObjectName ??
        (widget.objectOptions.isEmpty ? '' : widget.objectOptions.first);
    selectedEmployeeIds = Set<String>.from(
      widget.group?.employeeIds ?? const <String>{},
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    searchController.dispose();
    super.dispose();
  }

  List<Employee> get visibleEmployees {
    final query = searchController.text.trim().toLowerCase();
    final result = widget.employees.where((employee) {
      if (employee.objectName.trim() != objectName) return false;
      if (query.isEmpty) return true;
      return employee.name.toLowerCase().contains(query) ||
          employee.position.toLowerCase().contains(query);
    }).toList();
    result.sort((first, second) => first.name.compareTo(second.name));
    return result;
  }

  TimesheetGroup? currentGroupFor(String employeeId) {
    for (final group in widget.allGroups) {
      if (group.id == widget.group?.id) continue;
      if (group.employeeIds.contains(employeeId)) return group;
    }
    return null;
  }

  void changeObject(String value) {
    if (value == objectName) return;
    setState(() {
      objectName = value;
      selectedEmployeeIds = <String>{};
      searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final employees = visibleEmployees;
    return AlertDialog(
      title: Text(widget.group == null ? 'Новая группа' : 'Изменить группу'),
      content: SizedBox(
        width: 620,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.lockedObjectName == null && widget.group == null) ...[
              DropdownButtonFormField<String>(
                initialValue: objectName.isEmpty ? null : objectName,
                decoration: const InputDecoration(
                  labelText: 'Объект',
                  prefixIcon: Icon(Icons.apartment_outlined),
                ),
                items: widget.objectOptions
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) changeObject(value);
                },
              ),
              const SizedBox(height: 12),
            ] else ...[
              Text(
                objectName,
                style: TextStyle(
                  color: AppAdaptivePalette.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: nameController,
              autofocus: widget.group == null,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Название группы',
                hintText: 'Например: Бетонщики',
                prefixIcon: Icon(Icons.groups_2_outlined),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Сотрудники · выбрано ${selectedEmployeeIds.length}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: employees.isEmpty
                      ? null
                      : () => setState(() {
                          selectedEmployeeIds.addAll(
                            employees.map((employee) => employee.id).whereType<String>(),
                          );
                        }),
                  child: const Text('Выбрать всех'),
                ),
                TextButton(
                  onPressed: selectedEmployeeIds.isEmpty
                      ? null
                      : () => setState(selectedEmployeeIds.clear),
                  child: const Text('Снять'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: 'Поиск сотрудника',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: employees.isEmpty
                  ? Center(
                      child: Text(
                        'На этом объекте сотрудники не найдены',
                        style: TextStyle(color: AppAdaptivePalette.textMuted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: employees.length,
                      itemBuilder: (context, index) {
                        final employee = employees[index];
                        final employeeId = employee.id;
                        if (employeeId == null) return const SizedBox.shrink();
                        final otherGroup = currentGroupFor(employeeId);
                        return CheckboxListTile(
                          value: selectedEmployeeIds.contains(employeeId),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            employee.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            otherGroup == null
                                ? employee.position
                                : '${employee.position} · сейчас: ${otherGroup.name}',
                          ),
                          onChanged: (value) => setState(() {
                            if (value == true) {
                              selectedEmployeeIds.add(employeeId);
                            } else {
                              selectedEmployeeIds.remove(employeeId);
                            }
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: objectName.trim().isEmpty || nameController.text.trim().isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  _TimesheetGroupDraft(
                    objectName: objectName.trim(),
                    name: nameController.text.trim(),
                    employeeIds: Set<String>.from(selectedEmployeeIds),
                  ),
                ),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
''', encoding='utf-8')

Path('supabase/migrations/20260820161000_timesheet_employee_groups.sql').write_text(r'''-- Custom employee groups inside the timesheet.
-- Company admins manage membership; foremen can read/filter groups.

create table if not exists public.timesheet_groups (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  object_id uuid not null references public.objects(id) on delete cascade,
  name text not null,
  sort_order integer not null default 0,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint timesheet_groups_name_check
    check (char_length(btrim(name)) between 1 and 80)
);

create unique index if not exists timesheet_groups_company_object_name_uidx
  on public.timesheet_groups(company_id, object_id, lower(btrim(name)));
create index if not exists timesheet_groups_company_object_idx
  on public.timesheet_groups(company_id, object_id, sort_order, name);

create table if not exists public.timesheet_group_members (
  company_id uuid not null references public.companies(id) on delete cascade,
  group_id uuid not null references public.timesheet_groups(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  assigned_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (group_id, employee_id)
);

create unique index if not exists timesheet_group_members_company_employee_uidx
  on public.timesheet_group_members(company_id, employee_id);
create index if not exists timesheet_group_members_group_idx
  on public.timesheet_group_members(group_id, employee_id);

alter table public.timesheet_groups enable row level security;
alter table public.timesheet_group_members enable row level security;

drop policy if exists timesheet_groups_company_read on public.timesheet_groups;
create policy timesheet_groups_company_read
  on public.timesheet_groups
  for select
  to authenticated
  using (
    company_id = public.current_user_company_id()
    and public.current_user_role() in ('admin', 'foreman')
  );

drop policy if exists timesheet_group_members_company_read on public.timesheet_group_members;
create policy timesheet_group_members_company_read
  on public.timesheet_group_members
  for select
  to authenticated
  using (
    company_id = public.current_user_company_id()
    and public.current_user_role() in ('admin', 'foreman')
  );

grant select on public.timesheet_groups to authenticated;
grant select on public.timesheet_group_members to authenticated;

create or replace function public.list_timesheet_groups(
  p_object_name text default null
)
returns table (
  id uuid,
  object_id uuid,
  object_name text,
  name text,
  sort_order integer,
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
  group by g.id, g.object_id, o.name, g.name, g.sort_order
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
  v_employee_ids uuid[] := coalesce(p_employee_ids, '{}'::uuid[]);
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
    select coalesce(max(g.sort_order), 0) + 10
      into v_next_order
    from public.timesheet_groups g
    where g.company_id = v_company_id
      and g.object_id = v_object_id;

    insert into public.timesheet_groups (
      company_id,
      object_id,
      name,
      sort_order,
      created_by,
      updated_at
    ) values (
      v_company_id,
      v_object_id,
      v_name,
      v_next_order,
      (select auth.uid()),
      now()
    )
    returning id into v_group_id;
  else
    if not exists (
      select 1
      from public.timesheet_groups g
      where g.id = v_group_id
        and g.company_id = v_company_id
    ) then
      raise exception 'Группа не найдена';
    end if;

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
    -- An employee can be shown in only one timesheet section at a time.
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
begin
  if v_company_id is null or v_role <> 'admin' then
    raise exception 'Недостаточно прав для управления группами табеля'
      using errcode = '42501';
  end if;

  delete from public.timesheet_groups
  where id = p_group_id
    and company_id = v_company_id;
end;
$$;

revoke all on function public.list_timesheet_groups(text) from public;
revoke all on function public.save_timesheet_group(uuid, text, text, uuid[]) from public;
revoke all on function public.delete_timesheet_group(uuid) from public;
grant execute on function public.list_timesheet_groups(text) to authenticated;
grant execute on function public.save_timesheet_group(uuid, text, text, uuid[]) to authenticated;
grant execute on function public.delete_timesheet_group(uuid) to authenticated;

create or replace function private.cleanup_timesheet_group_members_on_employee_move()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.object_id is distinct from new.object_id
     or old.company_id is distinct from new.company_id
     or old.is_active is distinct from new.is_active then
    delete from public.timesheet_group_members m
    using public.timesheet_groups g
    where m.group_id = g.id
      and m.employee_id = new.id
      and (
        g.company_id <> new.company_id
        or g.object_id <> new.object_id
        or new.is_active is not true
      );
  end if;
  return new;
end;
$$;

drop trigger if exists employees_cleanup_timesheet_group_members on public.employees;
create trigger employees_cleanup_timesheet_group_members
  after update of object_id, company_id, is_active on public.employees
  for each row execute function private.cleanup_timesheet_group_members_on_employee_move();

drop trigger if exists timesheet_groups_app_data_broadcast on public.timesheet_groups;
create trigger timesheet_groups_app_data_broadcast
  after insert or update or delete on public.timesheet_groups
  for each row execute function private.broadcast_app_data_change();

drop trigger if exists timesheet_group_members_app_data_broadcast on public.timesheet_group_members;
create trigger timesheet_group_members_app_data_broadcast
  after insert or update or delete on public.timesheet_group_members
  for each row execute function private.broadcast_app_data_change();
''', encoding='utf-8')

# AppDataSync knows the new realtime domain.
replace_once(
    'lib/data/app_data_sync.dart',
    '''enum AppDataDomain {\n  attendance,\n  payments,''',
    '''enum AppDataDomain {\n  attendance,\n  timesheetGroups,\n  payments,''',
)
replace_once(
    'lib/data/app_data_sync.dart',
    '''        AppDataDomain.attendance,\n        AppDataDomain.payments,''',
    '''        AppDataDomain.attendance,\n        AppDataDomain.timesheetGroups,\n        AppDataDomain.payments,''',
)
replace_once(
    'lib/data/app_data_sync.dart',
    '''      case 'attendance':\n        return const <AppDataDomain>{AppDataDomain.attendance};\n      case 'payments':''',
    '''      case 'attendance':\n        return const <AppDataDomain>{AppDataDomain.attendance};\n      case 'timesheet_groups':\n      case 'timesheet_group_members':\n        return const <AppDataDomain>{AppDataDomain.timesheetGroups};\n      case 'payments':''',
)
replace_once(
    'lib/data/app_data_sync.dart',
    '''          AppDataDomain.attendance,\n          AppDataDomain.payments,''',
    '''          AppDataDomain.attendance,\n          AppDataDomain.timesheetGroups,\n          AppDataDomain.payments,''',
)

# Mobile/adaptive timesheet state.
replace_once(
    'lib/screens/timesheet_screen.dart',
    '''import '../features/timesheet/models/timesheet_draft.dart';''',
    '''import '../features/timesheet/data/timesheet_group_repository.dart';\nimport '../features/timesheet/models/timesheet_draft.dart';\nimport '../features/timesheet/models/timesheet_group.dart';''',
)
replace_once(
    'lib/screens/timesheet_screen.dart',
    '''import 'period_timesheet_screen.dart';''',
    '''import 'period_timesheet_screen.dart';\nimport 'timesheet_group_manager_sheet.dart';''',
)
replace_once(
    'lib/screens/timesheet_screen.dart',
    '''class _TimesheetScreenState extends State<TimesheetScreen> {\n  DateTime selectedDate = AppState.today;\n  Future<List<Employee>>? employeesFuture;\n  TimesheetDraft timesheetDraft = TimesheetDraft.empty();''',
    '''const String _allTimesheetGroupsFilter = '__all__';\nconst String _ungroupedTimesheetFilter = '__ungrouped__';\n\nclass _TimesheetEmployeeGroupSection {\n  final String title;\n  final List<Employee> employees;\n\n  const _TimesheetEmployeeGroupSection({\n    required this.title,\n    required this.employees,\n  });\n}\n\nclass _TimesheetScreenState extends State<TimesheetScreen> {\n  DateTime selectedDate = AppState.today;\n  Future<List<Employee>>? employeesFuture;\n  TimesheetDraft timesheetDraft = TimesheetDraft.empty();\n  List<TimesheetGroup> timesheetGroups = const <TimesheetGroup>[];\n  String selectedGroupFilter = _allTimesheetGroupsFilter;\n  bool isGroupsLoading = false;''',
)
replace_once(
    'lib/screens/timesheet_screen.dart',
    '''  bool get hasUnsavedChanges => timesheetDraft.hasChanges;''',
    '''  bool get hasUnsavedChanges => timesheetDraft.hasChanges;\n\n  bool get canManageTimesheetGroups =>\n      widget.profile.actualRole == 'admin' ||\n      widget.profile.actualRole == 'developer';''',
)
replace_once(
    'lib/screens/timesheet_screen.dart',
    '''    reloadEmployees();\n    loadAttendance();''',
    '''    reloadEmployees();\n    loadTimesheetGroups();\n    loadAttendance();''',
)
replace_once(
    'lib/screens/timesheet_screen.dart',
    '''      reloadEmployees(forceRefresh: true);\n      loadAttendance(forceRefresh: true);''',
    '''      reloadEmployees(forceRefresh: true);\n      loadTimesheetGroups(forceRefresh: true);\n      loadAttendance(forceRefresh: true);''',
)

# Mobile group loading.
replace_once(
    'lib/screens/timesheet/timesheet_loading.dart',
    '''  String get objectTitle =>\n      cleanObjectName(widget.selectedObjectName) ?? 'Все объекты';\n\n  Future<void> loadAttendance''',
    '''  String get objectTitle =>\n      cleanObjectName(widget.selectedObjectName) ?? 'Все объекты';\n\n  Future<void> loadTimesheetGroups({bool forceRefresh = false}) async {\n    if (mounted) setState(() => isGroupsLoading = true);\n    try {\n      final groups = await TimesheetGroupRepository.fetchGroups(\n        objectName: widget.selectedObjectName,\n      );\n      if (!mounted) return;\n      setState(() {\n        timesheetGroups = groups;\n        final filterExists = selectedGroupFilter == _allTimesheetGroupsFilter ||\n            selectedGroupFilter == _ungroupedTimesheetFilter ||\n            groups.any((group) => group.id == selectedGroupFilter);\n        if (!filterExists) selectedGroupFilter = _allTimesheetGroupsFilter;\n      });\n    } catch (error) {\n      if (!mounted) return;\n      setState(() => errorText = 'Ошибка загрузки групп табеля: $error');\n    } finally {\n      if (mounted) setState(() => isGroupsLoading = false);\n    }\n  }\n\n  Future<void> loadAttendance''',
)

# Mobile filtering, grouping, manager action.
replace_once(
    'lib/screens/timesheet/timesheet_actions.dart',
    '''  List<Employee> filterEmployees(List<Employee> employees) {\n    final searchText = searchController.text.trim().toLowerCase();\n    return employees.where((employee) {\n      return searchText.isEmpty ||\n          employee.name.toLowerCase().contains(searchText) ||\n          employee.position.toLowerCase().contains(searchText);\n    }).toList();\n  }''',
    '''  TimesheetGroup? groupForEmployee(Employee employee) {\n    for (final group in timesheetGroups) {\n      if (group.containsEmployee(employee.id)) return group;\n    }\n    return null;\n  }\n\n  bool employeeMatchesGroupFilter(Employee employee) {\n    if (selectedGroupFilter == _allTimesheetGroupsFilter) return true;\n    final group = groupForEmployee(employee);\n    if (selectedGroupFilter == _ungroupedTimesheetFilter) return group == null;\n    return group?.id == selectedGroupFilter;\n  }\n\n  String timesheetGroupTitle(TimesheetGroup group) {\n    if (cleanObjectName(widget.selectedObjectName) != null) return group.name;\n    return '${group.name} · ${group.objectName}';\n  }\n\n  List<Employee> filterEmployees(List<Employee> employees) {\n    final searchText = searchController.text.trim().toLowerCase();\n    final result = employees.where((employee) {\n      if (!employeeMatchesGroupFilter(employee)) return false;\n      return searchText.isEmpty ||\n          employee.name.toLowerCase().contains(searchText) ||\n          employee.position.toLowerCase().contains(searchText);\n    }).toList();\n    result.sort((first, second) => first.name.compareTo(second.name));\n    return result;\n  }\n\n  List<_TimesheetEmployeeGroupSection> employeeGroupSections(\n    List<Employee> visibleEmployees,\n  ) {\n    if (timesheetGroups.isEmpty) {\n      return <_TimesheetEmployeeGroupSection>[\n        _TimesheetEmployeeGroupSection(title: '', employees: visibleEmployees),\n      ];\n    }\n\n    final sections = <_TimesheetEmployeeGroupSection>[];\n    for (final group in timesheetGroups) {\n      if (selectedGroupFilter != _allTimesheetGroupsFilter &&\n          selectedGroupFilter != group.id) {\n        continue;\n      }\n      final employees = visibleEmployees\n          .where(group.containsEmployee)\n          .toList(growable: false);\n      if (employees.isNotEmpty) {\n        sections.add(\n          _TimesheetEmployeeGroupSection(\n            title: timesheetGroupTitle(group),\n            employees: employees,\n          ),\n        );\n      }\n    }\n\n    final ungrouped = visibleEmployees\n        .where((employee) => groupForEmployee(employee) == null)\n        .toList(growable: false);\n    if (ungrouped.isNotEmpty &&\n        (selectedGroupFilter == _allTimesheetGroupsFilter ||\n            selectedGroupFilter == _ungroupedTimesheetFilter)) {\n      sections.add(\n        _TimesheetEmployeeGroupSection(\n          title: 'Без группы',\n          employees: ungrouped,\n        ),\n      );\n    }\n    return sections;\n  }\n\n  Future<void> openTimesheetGroupManager(List<Employee> employees) async {\n    if (!canManageTimesheetGroups) return;\n    final changed = await TimesheetGroupManagerSheet.show(\n      context,\n      selectedObjectName: widget.selectedObjectName,\n      employees: employees,\n      groups: timesheetGroups,\n    );\n    if (changed && mounted) {\n      await loadTimesheetGroups(forceRefresh: true);\n    }\n  }''',
)

# Mobile group filter and section headers.
replace_once(
    'lib/screens/timesheet/timesheet_sections.dart',
    '''  Widget buildQuickActions(List<Employee> visibleEmployees) {''',
    '''  Widget buildGroupFilter(List<Employee> allEmployees) {\n    final groupIds = timesheetGroups.map((group) => group.id).toSet();\n    final currentValue = selectedGroupFilter == _allTimesheetGroupsFilter ||\n            selectedGroupFilter == _ungroupedTimesheetFilter ||\n            groupIds.contains(selectedGroupFilter)\n        ? selectedGroupFilter\n        : _allTimesheetGroupsFilter;\n\n    return PremiumWorkCard(\n      radius: 20,\n      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),\n      child: Row(\n        children: [\n          Icon(Icons.groups_2_outlined, color: AppAdaptivePalette.textMuted),\n          const SizedBox(width: 10),\n          Expanded(\n            child: DropdownButtonHideUnderline(\n              child: DropdownButton<String>(\n                value: currentValue,\n                isExpanded: true,\n                items: <DropdownMenuItem<String>>[\n                  const DropdownMenuItem<String>(\n                    value: _allTimesheetGroupsFilter,\n                    child: Text('Все группы'),\n                  ),\n                  ...timesheetGroups.map(\n                    (group) => DropdownMenuItem<String>(\n                      value: group.id,\n                      child: Text(\n                        timesheetGroupTitle(group),\n                        overflow: TextOverflow.ellipsis,\n                      ),\n                    ),\n                  ),\n                  const DropdownMenuItem<String>(\n                    value: _ungroupedTimesheetFilter,\n                    child: Text('Без группы'),\n                  ),\n                ],\n                onChanged: isGroupsLoading\n                    ? null\n                    : (value) {\n                        if (value != null) {\n                          setState(() => selectedGroupFilter = value);\n                        }\n                      },\n              ),\n            ),\n          ),\n          if (canManageTimesheetGroups) ...[\n            const SizedBox(width: 8),\n            OutlinedButton.icon(\n              onPressed: isGroupsLoading\n                  ? null\n                  : () => openTimesheetGroupManager(allEmployees),\n              icon: const Icon(Icons.tune_rounded, size: 18),\n              label: const Text('Группы'),\n            ),\n          ],\n        ],\n      ),\n    );\n  }\n\n  Widget buildGroupHeader(String title, int count) {\n    return Padding(\n      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),\n      child: Row(\n        children: [\n          Expanded(\n            child: Text(\n              title,\n              style: TextStyle(\n                color: AppAdaptivePalette.textPrimary,\n                fontSize: 15,\n                fontWeight: FontWeight.w900,\n              ),\n            ),\n          ),\n          Text(\n            '$count чел.',\n            style: TextStyle(\n              color: AppAdaptivePalette.textMuted,\n              fontSize: 12,\n              fontWeight: FontWeight.w700,\n            ),\n          ),\n        ],\n      ),\n    );\n  }\n\n  List<Widget> buildGroupedEmployeeItems(List<Employee> visibleEmployees) {\n    final sections = employeeGroupSections(visibleEmployees);\n    final widgets = <Widget>[];\n    for (final section in sections) {\n      if (section.title.isNotEmpty) {\n        widgets.add(buildGroupHeader(section.title, section.employees.length));\n      }\n      widgets.addAll(\n        section.employees.map(\n          (employee) => RepaintBoundary(child: buildEmployeeRow(employee)),\n        ),\n      );\n    }\n    return widgets;\n  }\n\n  Widget buildQuickActions(List<Employee> visibleEmployees) {''',
)

# Mobile list uses grouped widgets and filter.
replace_once(
    'lib/screens/timesheet/timesheet_view.dart',
    '''            final visibleEmployees = filterEmployees(allEmployees);\n            final floatingBottom''',
    '''            final visibleEmployees = filterEmployees(allEmployees);\n            final employeeItems = buildGroupedEmployeeItems(visibleEmployees);\n            final floatingBottom''',
)
replace_once(
    'lib/screens/timesheet/timesheet_view.dart',
    '''                            buildSearch(),\n                            const SizedBox(height: 16),\n                            buildQuickActions(visibleEmployees),''',
    '''                            buildSearch(),\n                            const SizedBox(height: 12),\n                            buildGroupFilter(allEmployees),\n                            const SizedBox(height: 16),\n                            buildQuickActions(visibleEmployees),''',
)
replace_once(
    'lib/screens/timesheet/timesheet_view.dart',
    '''                            itemCount: leading.length + visibleEmployees.length,\n                            itemBuilder: (context, index) {\n                              if (index < leading.length) return leading[index];\n                              final employee =\n                                  visibleEmployees[index - leading.length];\n                              return RepaintBoundary(\n                                child: buildEmployeeRow(employee),\n                              );\n                            },''',
    '''                            itemCount: leading.length + employeeItems.length,\n                            itemBuilder: (context, index) {\n                              if (index < leading.length) return leading[index];\n                              return employeeItems[index - leading.length];\n                            },''',
)

# Mobile reacts to remote group updates.
replace_once(
    'lib/screens/timesheet/timesheet_sync.dart',
    '''    if (change.affectsAny(const <AppDataDomain>{\n      AppDataDomain.employees,\n      AppDataDomain.objects,\n    })) {\n      setState(() => reloadEmployees(forceRefresh: true));\n    }\n\n    final attendanceChanged''',
    '''    if (change.affectsAny(const <AppDataDomain>{\n      AppDataDomain.employees,\n      AppDataDomain.objects,\n    })) {\n      setState(() => reloadEmployees(forceRefresh: true));\n    }\n\n    if (change.affectsAny(const <AppDataDomain>{\n      AppDataDomain.timesheetGroups,\n      AppDataDomain.employees,\n      AppDataDomain.objects,\n    })) {\n      loadTimesheetGroups(forceRefresh: true);\n    }\n\n    final attendanceChanged''',
)

# Desktop imports and state.
replace_once(
    'lib/screens/desktop_timesheet_screen.dart',
    '''import '../data/employee_repository.dart';\nimport '../models/app_user_profile.dart';''',
    '''import '../data/employee_repository.dart';\nimport '../features/timesheet/data/timesheet_group_repository.dart';\nimport '../features/timesheet/models/timesheet_group.dart';\nimport '../models/app_user_profile.dart';''',
)
replace_once(
    'lib/screens/desktop_timesheet_screen.dart',
    '''import 'period_timesheet_screen.dart';''',
    '''import 'period_timesheet_screen.dart';\nimport 'timesheet_group_manager_sheet.dart';''',
)
replace_once(
    'lib/screens/desktop_timesheet_screen.dart',
    '''  List<Employee> employees = const <Employee>[];\n  Map<String, double> shiftValuesByEmployeeId''',
    '''  List<Employee> employees = const <Employee>[];\n  List<TimesheetGroup> timesheetGroups = const <TimesheetGroup>[];\n  Map<String, double> shiftValuesByEmployeeId''',
)
replace_once(
    'lib/screens/desktop_timesheet_screen.dart',
    '''  String? objectFilter;\n  String attendanceFilter = 'Все сотрудники';''',
    '''  static const String allGroupsFilter = '__all__';\n  static const String ungroupedFilter = '__ungrouped__';\n\n  String? objectFilter;\n  String groupFilter = allGroupsFilter;\n  String attendanceFilter = 'Все сотрудники';''',
)
replace_once(
    'lib/screens/desktop_timesheet_screen.dart',
    '''  static const List<double> quickOptions = <double>[0, 0.5, 1, 1.5, 2];''',
    '''  static const List<double> quickOptions = <double>[0, 0.5, 1, 1.5, 2];\n\n  bool get canManageTimesheetGroups =>\n      widget.profile.actualRole == 'admin' ||\n      widget.profile.actualRole == 'developer';''',
)
replace_once(
    'lib/screens/desktop_timesheet_screen.dart',
    '''      attendanceFilter = 'Все сотрудники';\n      searchController.clear();''',
    '''      attendanceFilter = 'Все сотрудники';\n      groupFilter = allGroupsFilter;\n      searchController.clear();''',
)

# Desktop realtime group handling.
replace_once(
    'lib/screens/desktop_timesheet_screen.dart',
    '''    if (employeesChanged) {\n      loadData(forceRefresh: true, attendanceOnly: false);\n      return;\n    }\n\n    if (!attendanceChanged''',
    '''    final groupsChanged = change.affectsAny(const <AppDataDomain>{\n      AppDataDomain.timesheetGroups,\n    });\n\n    if (employeesChanged || groupsChanged) {\n      loadData(forceRefresh: true, attendanceOnly: false);\n      return;\n    }\n\n    if (!attendanceChanged''',
)

# Desktop load groups together with employees/attendance.
replace_once(
    'lib/screens/desktop_timesheet_screen.dart',
    '''      final results = await Future.wait<dynamic>([\n        employeeFuture,\n        AttendanceRepository.fetchShiftValuesForDate(\n          requestedDate,\n          objectName: requestedObject,\n          forceRefresh: forceRefresh,\n        ),\n      ]);''',
    '''      final groupFuture = attendanceOnly\n          ? Future<List<TimesheetGroup>>.value(timesheetGroups)\n          : TimesheetGroupRepository.fetchGroups(objectName: requestedObject);\n      final results = await Future.wait<dynamic>([\n        employeeFuture,\n        AttendanceRepository.fetchShiftValuesForDate(\n          requestedDate,\n          objectName: requestedObject,\n          forceRefresh: forceRefresh,\n        ),\n        groupFuture,\n      ]);''',
)
replace_once(
    'lib/screens/desktop_timesheet_screen.dart',
    '''      final loadedEmployees = results[0] as List<Employee>;\n      final loadedValues = results[1] as Map<String, double>;''',
    '''      final loadedEmployees = results[0] as List<Employee>;\n      final loadedValues = results[1] as Map<String, double>;\n      final loadedGroups = results[2] as List<TimesheetGroup>;''',
)
replace_once(
    'lib/screens/desktop_timesheet_screen.dart',
    '''        employees = loadedEmployees;\n        shiftValuesByEmployeeId = Map<String, double>.from(loadedValues);''',
    '''        employees = loadedEmployees;\n        timesheetGroups = loadedGroups;\n        shiftValuesByEmployeeId = Map<String, double>.from(loadedValues);''',
)
replace_once(
    'lib/screens/desktop_timesheet_screen.dart',
    '''        } else if (objectFilter != null &&\n            !availableObjects.contains(objectFilter)) {\n          objectFilter = null;\n        }\n      });''',
    '''        } else if (objectFilter != null &&\n            !availableObjects.contains(objectFilter)) {\n          objectFilter = null;\n        }\n\n        final filterExists = groupFilter == allGroupsFilter ||\n            groupFilter == ungroupedFilter ||\n            loadedGroups.any((group) => group.id == groupFilter);\n        if (!filterExists) groupFilter = allGroupsFilter;\n      });''',
)

# Desktop group helpers + filtering/sorting.
replace_once(
    'lib/screens/desktop_timesheet_screen.dart',
    '''  List<Employee> visibleEmployees() {''',
    '''  List<TimesheetGroup> get groupOptions {\n    final selectedObject = cleanObjectName(objectFilter);\n    final result = timesheetGroups.where((group) {\n      return selectedObject == null || group.objectName == selectedObject;\n    }).toList();\n    result.sort((first, second) {\n      final objectCompare = first.objectName.compareTo(second.objectName);\n      if (objectCompare != 0) return objectCompare;\n      final orderCompare = first.sortOrder.compareTo(second.sortOrder);\n      if (orderCompare != 0) return orderCompare;\n      return first.name.compareTo(second.name);\n    });\n    return result;\n  }\n\n  TimesheetGroup? groupForEmployee(Employee employee) {\n    for (final group in timesheetGroups) {\n      if (group.containsEmployee(employee.id)) return group;\n    }\n    return null;\n  }\n\n  String groupOptionTitle(TimesheetGroup group) {\n    final selectedObject = cleanObjectName(objectFilter);\n    if (selectedObject != null) return group.name;\n    return '${group.name} · ${group.objectName}';\n  }\n\n  bool employeeMatchesGroupFilter(Employee employee) {\n    if (groupFilter == allGroupsFilter) return true;\n    final group = groupForEmployee(employee);\n    if (groupFilter == ungroupedFilter) return group == null;\n    return group?.id == groupFilter;\n  }\n\n  int groupSortIndex(Employee employee) {\n    final group = groupForEmployee(employee);\n    if (group == null) return 1 << 30;\n    final index = timesheetGroups.indexWhere((value) => value.id == group.id);\n    return index < 0 ? 1 << 29 : index;\n  }\n\n  Future<void> openTimesheetGroupManager() async {\n    if (!canManageTimesheetGroups) return;\n    final changed = await TimesheetGroupManagerSheet.show(\n      context,\n      selectedObjectName: widget.selectedObjectName,\n      employees: employees,\n      groups: timesheetGroups,\n    );\n    if (changed && mounted) {\n      groupFilter = allGroupsFilter;\n      await loadData(forceRefresh: true, attendanceOnly: false);\n    }\n  }\n\n  List<Employee> visibleEmployees() {''',
)
replace_once(
    'lib/screens/desktop_timesheet_screen.dart',
    '''      final shift = shiftValueFor(employee);\n      if (attendanceFilter == 'Только вышедшие' && shift <= 0) return false;''',
    '''      if (!employeeMatchesGroupFilter(employee)) return false;\n\n      final shift = shiftValueFor(employee);\n      if (attendanceFilter == 'Только вышедшие' && shift <= 0) return false;''',
)
replace_once(
    'lib/screens/desktop_timesheet_screen.dart',
    '''    result.sort((first, second) {\n      final object = first.objectName.compareTo(second.objectName);\n      if (object != 0) return object;\n      return first.name.compareTo(second.name);\n    });''',
    '''    result.sort((first, second) {\n      final object = first.objectName.compareTo(second.objectName);\n      if (object != 0) return object;\n      final group = groupSortIndex(first).compareTo(groupSortIndex(second));\n      if (group != 0) return group;\n      return first.name.compareTo(second.name);\n    });''',
)

# Replace desktop filter card with a roomier two-row layout including groups.
regex_once(
    'lib/screens/desktop_timesheet_screen.dart',
    r'''  Widget buildFilters\(List<Employee> visible\) \{.*?\n  \}\n\n  Widget buildTable\(List<Employee> visible\) \{''',
    r'''  Widget buildFilters(List<Employee> visible) {
    final lockedObject = cleanObjectName(widget.selectedObjectName);
    final currentGroups = groupOptions;
    final validGroupValues = <String>{
      allGroupsFilter,
      ungroupedFilter,
      ...currentGroups.map((group) => group.id),
    };
    final currentGroupFilter = validGroupValues.contains(groupFilter)
        ? groupFilter
        : allGroupsFilter;

    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Поиск по ФИО, должности или объекту',
                    prefixIcon: Icon(Icons.search_rounded),
                    suffixIcon: searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              searchController.clear();
                              setState(() {});
                            },
                            icon: Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: _soft,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _DropdownShell(
                  icon: Icons.apartment_outlined,
                  child: DropdownButton<String?>(
                    value: lockedObject ?? objectFilter,
                    isExpanded: true,
                    items: <DropdownMenuItem<String?>>[
                      if (lockedObject == null)
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Все объекты'),
                        ),
                      ...objectOptions.map(
                        (objectName) => DropdownMenuItem<String?>(
                          value: objectName,
                          child: Text(objectName, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: lockedObject == null
                        ? (value) => setState(() {
                            objectFilter = value;
                            groupFilter = allGroupsFilter;
                          })
                        : null,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _DropdownShell(
                  icon: Icons.groups_2_outlined,
                  child: DropdownButton<String>(
                    value: currentGroupFilter,
                    isExpanded: true,
                    items: <DropdownMenuItem<String>>[
                      const DropdownMenuItem<String>(
                        value: allGroupsFilter,
                        child: Text('Все группы'),
                      ),
                      ...currentGroups.map(
                        (group) => DropdownMenuItem<String>(
                          value: group.id,
                          child: Text(
                            groupOptionTitle(group),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const DropdownMenuItem<String>(
                        value: ungroupedFilter,
                        child: Text('Без группы'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => groupFilter = value);
                    },
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _DropdownShell(
                  icon: Icons.filter_alt_outlined,
                  child: DropdownButton<String>(
                    value: attendanceFilter,
                    isExpanded: true,
                    items: const <String>[
                      'Все сотрудники',
                      'Только вышедшие',
                      'Не вышли',
                    ].map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    ).toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => attendanceFilter = value);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Быстрый ввод',
                style: TextStyle(
                  color: _muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (canManageTimesheetGroups) ...[
                OutlinedButton.icon(
                  onPressed: isLoading || isSaving
                      ? null
                      : openTimesheetGroupManager,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Группы'),
                ),
                const SizedBox(width: 10),
              ],
              FilledButton.tonalIcon(
                onPressed: visible.isEmpty || isLoading || isSaving
                    ? null
                    : () => setVisibleShifts(visible, 1),
                icon: Icon(Icons.done_all_rounded),
                label: const Text('Всем 1'),
              ),
              SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: visible.isEmpty || isLoading || isSaving
                    ? null
                    : () => setVisibleShifts(visible, 0),
                icon: Icon(Icons.remove_done_rounded),
                label: const Text('Всем 0'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> buildGroupedTableRows(List<Employee> visible) {
    if (timesheetGroups.isEmpty) {
      return visible
          .map<Widget>(
            (employee) => _TimesheetRow(
              employee: employee,
              value: shiftValueFor(employee),
              formatShift: formatShift,
              enabled: !isLoading && !isSaving,
              onSelected: (value) => setShiftValue(employee, value),
              onCustom: () => showShiftPicker(employee),
            ),
          )
          .toList(growable: false);
    }

    final rows = <Widget>[];
    final currentGroups = groupOptions;
    for (final group in currentGroups) {
      if (groupFilter != allGroupsFilter && groupFilter != group.id) continue;
      final members = visible.where(group.containsEmployee).toList();
      if (members.isEmpty) continue;
      rows.add(
        _TimesheetGroupTableHeader(
          title: groupOptionTitle(group),
          count: members.length,
        ),
      );
      rows.addAll(
        members.map(
          (employee) => _TimesheetRow(
            employee: employee,
            value: shiftValueFor(employee),
            formatShift: formatShift,
            enabled: !isLoading && !isSaving,
            onSelected: (value) => setShiftValue(employee, value),
            onCustom: () => showShiftPicker(employee),
          ),
        ),
      );
    }

    final ungrouped = visible
        .where((employee) => groupForEmployee(employee) == null)
        .toList();
    if (ungrouped.isNotEmpty &&
        (groupFilter == allGroupsFilter || groupFilter == ungroupedFilter)) {
      rows.add(
        _TimesheetGroupTableHeader(title: 'Без группы', count: ungrouped.length),
      );
      rows.addAll(
        ungrouped.map(
          (employee) => _TimesheetRow(
            employee: employee,
            value: shiftValueFor(employee),
            formatShift: formatShift,
            enabled: !isLoading && !isSaving,
            onSelected: (value) => setShiftValue(employee, value),
            onCustom: () => showShiftPicker(employee),
          ),
        ),
      );
    }
    return rows;
  }

  Widget buildTable(List<Employee> visible) {''',
)
replace_once(
    'lib/screens/desktop_timesheet_screen.dart',
    '''            else\n              ...visible.map(\n                (employee) => _TimesheetRow(\n                  employee: employee,\n                  value: shiftValueFor(employee),\n                  formatShift: formatShift,\n                  enabled: !isLoading && !isSaving,\n                  onSelected: (value) => setShiftValue(employee, value),\n                  onCustom: () => showShiftPicker(employee),\n                ),\n              ),''',
    '''            else\n              ...buildGroupedTableRows(visible),''',
)

# Add desktop group section row before the existing table header widget.
replace_once(
    'lib/screens/desktop_timesheet_screen.dart',
    '''class _TableHeader extends StatelessWidget {''',
    '''class _TimesheetGroupTableHeader extends StatelessWidget {\n  final String title;\n  final int count;\n\n  const _TimesheetGroupTableHeader({required this.title, required this.count});\n\n  @override\n  Widget build(BuildContext context) {\n    return Container(\n      padding: const EdgeInsets.fromLTRB(18, 13, 18, 10),\n      decoration: BoxDecoration(\n        color: AppAdaptivePalette.surfaceSoft,\n        border: Border(\n          bottom: BorderSide(color: AppAdaptivePalette.border),\n        ),\n      ),\n      child: Row(\n        children: [\n          Icon(Icons.groups_2_outlined, size: 18, color: _muted),\n          const SizedBox(width: 8),\n          Expanded(\n            child: Text(\n              title,\n              style: TextStyle(\n                color: _text,\n                fontWeight: FontWeight.w900,\n              ),\n            ),\n          ),\n          Text(\n            '$count чел.',\n            style: TextStyle(\n              color: _muted,\n              fontSize: 12,\n              fontWeight: FontWeight.w700,\n            ),\n          ),\n        ],\n      ),\n    );\n  }\n}\n\nclass _TableHeader extends StatelessWidget {''',
)

Path('test/timesheet_groups_test.dart').write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/timesheet/models/timesheet_group.dart';

void main() {
  test('timesheet group maps members and keeps one display label', () {
    final group = TimesheetGroup.fromMap(<String, dynamic>{
      'id': 'group-1',
      'object_id': 'object-1',
      'object_name': 'Мурманск',
      'name': 'Бетонщики',
      'sort_order': 10,
      'employee_ids': <String>['employee-1', 'employee-2'],
    });

    expect(group.name, 'Бетонщики');
    expect(group.employeeIds, containsAll(<String>['employee-1', 'employee-2']));
    expect(group.containsEmployee('employee-1'), isTrue);
    expect(group.containsEmployee('employee-3'), isFalse);
  });

  test('timesheet UI contains group filter, manager and section headers', () {
    final mobile = File('lib/screens/timesheet/timesheet_sections.dart')
        .readAsStringSync();
    final desktop = File('lib/screens/desktop_timesheet_screen.dart')
        .readAsStringSync();
    final manager = File('lib/screens/timesheet_group_manager_sheet.dart')
        .readAsStringSync();

    expect(mobile, contains("Text('Все группы')"));
    expect(mobile, contains("Text('Без группы')"));
    expect(mobile, contains("Text('Группы')"));
    expect(desktop, contains('groupFilter = allGroupsFilter'));
    expect(desktop, contains('_TimesheetGroupTableHeader'));
    expect(manager, contains("'Создать группу'"));
    expect(manager, contains("'Название группы'"));
    expect(manager, contains("'Сотрудники · выбрано"));
  });

  test('database keeps timesheet groups company scoped and admin managed', () {
    final migration = File(
      'supabase/migrations/20260820161000_timesheet_employee_groups.sql',
    ).readAsStringSync();

    expect(migration, contains('create table if not exists public.timesheet_groups'));
    expect(migration, contains('create table if not exists public.timesheet_group_members'));
    expect(migration, contains('public.current_user_company_id()'));
    expect(migration, contains("v_role <> 'admin'"));
    expect(migration, contains('timesheet_group_members_company_employee_uidx'));
    expect(migration, contains('list_timesheet_groups'));
    expect(migration, contains('save_timesheet_group'));
    expect(migration, contains('delete_timesheet_group'));
  });
}
''', encoding='utf-8')

print('timesheet groups patch applied')
