import 'package:flutter/material.dart';

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
    final values = <String>{};
    final selectedObject = cleanObjectName(widget.selectedObjectName);
    if (selectedObject != null) values.add(selectedObject);
    values.addAll(
      widget.employees
          .map((employee) => employee.objectName.trim())
          .where((value) => value.isNotEmpty),
    );
    final result = values.toList()..sort();
    return result;
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
            color: Theme.of(context).colorScheme.surface,
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
                            employees
                                .map((employee) => employee.id)
                                .whereType<String>(),
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
          onPressed:
              objectName.trim().isEmpty || nameController.text.trim().isEmpty
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
