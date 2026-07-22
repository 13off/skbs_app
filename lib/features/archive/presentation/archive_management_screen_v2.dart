import 'package:flutter/material.dart';

import '../../../data/employee_repository.dart';
import '../../../data/object_repository.dart';
import '../../../data/permanent_deletion_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../models/construction_object.dart';
import '../../../models/employee.dart';

enum _ArchiveKind { employees, objects }

class ArchiveManagementScreenV2 extends StatefulWidget {
  final AppUserProfile profile;

  const ArchiveManagementScreenV2({super.key, required this.profile});

  @override
  State<ArchiveManagementScreenV2> createState() =>
      _ArchiveManagementScreenV2State();
}

class _ArchiveManagementScreenV2State
    extends State<ArchiveManagementScreenV2> {
  final TextEditingController searchController = TextEditingController();

  _ArchiveKind kind = _ArchiveKind.employees;
  bool showArchived = false;
  bool isLoading = true;
  bool isBusy = false;
  String? errorText;

  List<Employee> employees = <Employee>[];
  List<ConstructionObject> activeObjects = <ConstructionObject>[];
  List<String> archivedObjects = <String>[];

  final Set<String> selectedEmployeeIds = <String>{};
  final Set<String> selectedObjectNames = <String>{};

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadData({bool loader = true}) async {
    if (loader) {
      setState(() {
        isLoading = true;
        errorText = null;
      });
    }

    try {
      final result = await Future.wait<dynamic>([
        EmployeeRepository.fetchEmployees(
          includeFired: true,
          forceRefresh: true,
        ),
        ObjectRepository.fetchObjects(forceRefresh: true),
        ObjectRepository.fetchArchivedObjectNames(forceRefresh: true),
      ]);

      if (!mounted) return;

      setState(() {
        employees = result[0] as List<Employee>;
        activeObjects = result[1] as List<ConstructionObject>;
        archivedObjects = result[2] as List<String>;
        selectedEmployeeIds.removeWhere(
          (id) => !employees.any((employee) => employee.id == id),
        );
        selectedObjectNames.removeWhere(
          (name) =>
              !activeObjects.any((object) => object.name == name) &&
              !archivedObjects.contains(name),
        );
        isLoading = false;
        errorText = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorText = error.toString();
      });
    }
  }

  List<Employee> visibleEmployees() {
    final query = searchController.text.trim().toLowerCase();
    final result = employees.where((employee) {
      final archived = !employee.isActive;
      if (archived != showArchived) return false;
      if (query.isEmpty) return true;
      return employee.name.toLowerCase().contains(query) ||
          employee.position.toLowerCase().contains(query) ||
          employee.objectName.toLowerCase().contains(query) ||
          employee.phone.toLowerCase().contains(query);
    }).toList();

    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  List<String> visibleObjects() {
    final query = searchController.text.trim().toLowerCase();
    final result = showArchived
        ? List<String>.from(archivedObjects)
        : activeObjects.map((object) => object.name).toList();
    result.removeWhere((name) => !name.toLowerCase().contains(query));
    result.sort();
    return result;
  }

  int get selectedCount => kind == _ArchiveKind.employees
      ? selectedEmployeeIds.length
      : selectedObjectNames.length;

  void clearSelection() {
    setState(() {
      selectedEmployeeIds.clear();
      selectedObjectNames.clear();
    });
  }

  void selectAllVisible(bool selected) {
    setState(() {
      if (kind == _ArchiveKind.employees) {
        final ids = visibleEmployees()
            .map((employee) => employee.id?.trim() ?? '')
            .where((id) => id.isNotEmpty);
        if (selected) {
          selectedEmployeeIds.addAll(ids);
        } else {
          selectedEmployeeIds.removeAll(ids);
        }
      } else {
        final names = visibleObjects();
        if (selected) {
          selectedObjectNames.addAll(names);
        } else {
          selectedObjectNames.removeAll(names);
        }
      }
    });
  }

  bool get allVisibleSelected {
    if (kind == _ArchiveKind.employees) {
      final ids = visibleEmployees()
          .map((employee) => employee.id?.trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      return ids.isNotEmpty && ids.every(selectedEmployeeIds.contains);
    }

    final names = visibleObjects();
    return names.isNotEmpty && names.every(selectedObjectNames.contains);
  }

  Future<bool> confirm(String title, String message, String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<bool> confirmDeleteMany() async {
    final controller = TextEditingController();
    bool matches = false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Удалить выбранное навсегда?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Будет безвозвратно удалено: $selectedCount. Восстановить данные будет невозможно.',
              ),
              const SizedBox(height: 14),
              const Text(
                'Введите УДАЛИТЬ',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                onChanged: (value) {
                  setDialogState(() => matches = value.trim() == 'УДАЛИТЬ');
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton.icon(
              onPressed: matches ? () => Navigator.pop(context, true) : null,
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Удалить навсегда'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result == true;
  }

  Future<void> archiveOrRestoreSelected() async {
    if (selectedCount == 0 || isBusy) return;

    final archive = !showArchived;
    final confirmed = await confirm(
      archive ? 'Архивировать выбранное?' : 'Восстановить выбранное?',
      archive
          ? 'Выбранные элементы исчезнут из рабочих списков, но все данные сохранятся.'
          : 'Выбранные элементы снова появятся в рабочих списках.',
      archive ? 'В архив' : 'Восстановить',
    );
    if (!confirmed || !mounted) return;

    setState(() => isBusy = true);
    try {
      if (kind == _ArchiveKind.employees) {
        for (final id in selectedEmployeeIds.toList()) {
          await EmployeeRepository.setEmployeeActive(
            employeeId: id,
            isActive: !archive,
          );
        }
      } else {
        for (final name in selectedObjectNames.toList()) {
          if (archive) {
            await ObjectRepository.archiveObject(name: name);
          } else {
            await ObjectRepository.restoreObject(name: name);
          }
        }
      }

      clearSelection();
      await loadData(loader: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(archive ? 'Выбранное перемещено в архив' : 'Выбранное восстановлено'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $error')),
      );
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  Future<void> deleteSelectedForever() async {
    if (!showArchived || selectedCount == 0 || isBusy) return;
    if (!await confirmDeleteMany() || !mounted) return;

    setState(() => isBusy = true);
    try {
      if (kind == _ArchiveKind.employees) {
        for (final id in selectedEmployeeIds.toList()) {
          await PermanentDeletionRepository.deleteArchivedEmployee(id);
        }
      } else {
        for (final name in selectedObjectNames.toList()) {
          await PermanentDeletionRepository.deleteArchivedObject(name);
        }
      }

      clearSelection();
      await loadData(loader: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выбранное удалено навсегда')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка удаления: $error')),
      );
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  Widget buildTopPanel() {
    return Column(
      children: [
        SegmentedButton<_ArchiveKind>(
          segments: const [
            ButtonSegment(
              value: _ArchiveKind.employees,
              icon: Icon(Icons.groups_outlined),
              label: Text('Сотрудники'),
            ),
            ButtonSegment(
              value: _ArchiveKind.objects,
              icon: Icon(Icons.apartment_outlined),
              label: Text('Объекты'),
            ),
          ],
          selected: {kind},
          onSelectionChanged: isBusy
              ? null
              : (value) {
                  setState(() {
                    kind = value.first;
                    searchController.clear();
                    clearSelection();
                  });
                },
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Активные')),
            ButtonSegment(value: true, label: Text('Архив')),
          ],
          selected: {showArchived},
          onSelectionChanged: isBusy
              ? null
              : (value) {
                  setState(() {
                    showArchived = value.first;
                    clearSelection();
                  });
                },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: kind == _ArchiveKind.employees
                ? 'Поиск сотрудника'
                : 'Поиск объекта',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: allVisibleSelected,
          onChanged: isBusy
              ? null
              : (value) => selectAllVisible(value == true),
          title: const Text(
            'Выбрать все',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text('Выбрано: $selectedCount'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }

  Widget buildEmployeeRow(Employee employee) {
    final id = employee.id?.trim() ?? '';
    final selected = selectedEmployeeIds.contains(id);
    return CheckboxListTile(
      value: selected,
      onChanged: id.isEmpty || isBusy
          ? null
          : (value) {
              setState(() {
                if (value == true) {
                  selectedEmployeeIds.add(id);
                } else {
                  selectedEmployeeIds.remove(id);
                }
              });
            },
      title: Text(
        employee.name,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        [employee.position, employee.objectName, employee.phone]
            .where((value) => value.trim().isNotEmpty)
            .join(' • '),
      ),
      secondary: Icon(
        showArchived ? Icons.inventory_2_outlined : Icons.person_outline,
      ),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget buildObjectRow(String objectName) {
    final selected = selectedObjectNames.contains(objectName);
    return CheckboxListTile(
      value: selected,
      onChanged: isBusy
          ? null
          : (value) {
              setState(() {
                if (value == true) {
                  selectedObjectNames.add(objectName);
                } else {
                  selectedObjectNames.remove(objectName);
                }
              });
            },
      title: Text(
        objectName,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(showArchived ? 'В архиве' : 'Действующий объект'),
      secondary: Icon(
        showArchived ? Icons.inventory_2_outlined : Icons.apartment_outlined,
      ),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget buildList() {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (errorText != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(errorText!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: loadData, child: const Text('Повторить')),
          ],
        ),
      );
    }

    final items = kind == _ArchiveKind.employees
        ? visibleEmployees().map(buildEmployeeRow).toList()
        : visibleObjects().map(buildObjectRow).toList();

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: Text('Ничего не найдено')),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            items[index],
            if (index < items.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.profile.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Доступно только администратору')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Архив и удаление'),
        actions: [
          IconButton(
            onPressed: isBusy ? null : () => loadData(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: buildTopPanel(),
              ),
            ),
            const SizedBox(height: 14),
            buildList(),
          ],
        ),
      ),
      bottomNavigationBar: selectedCount == 0
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isBusy ? null : archiveOrRestoreSelected,
                      icon: isBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              showArchived
                                  ? Icons.restore_outlined
                                  : Icons.archive_outlined,
                            ),
                      label: Text(
                        showArchived ? 'Восстановить' : 'В архив',
                      ),
                    ),
                  ),
                  if (showArchived) ...[
                    const SizedBox(width: 10),
                    IconButton.filled(
                      tooltip: 'Удалить выбранное навсегда',
                      onPressed: isBusy ? null : deleteSelectedForever,
                      icon: const Icon(Icons.delete_forever_outlined),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
