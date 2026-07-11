import 'package:flutter/material.dart';

import '../../../data/employee_archive_repository.dart';
import '../../../data/object_repository.dart';
import '../../../data/permanent_deletion_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../models/employee.dart';

enum _ArchiveKind { employees, objects }

class ArchiveManagementScreenV3 extends StatefulWidget {
  final AppUserProfile profile;

  const ArchiveManagementScreenV3({super.key, required this.profile});

  @override
  State<ArchiveManagementScreenV3> createState() =>
      _ArchiveManagementScreenV3State();
}

class _ArchiveManagementScreenV3State extends State<ArchiveManagementScreenV3> {
  final TextEditingController searchController = TextEditingController();

  _ArchiveKind kind = _ArchiveKind.employees;
  bool isLoading = true;
  bool isBusy = false;
  String? errorText;

  List<Employee> archivedEmployees = <Employee>[];
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
        EmployeeArchiveRepository.fetchArchivedEmployees(),
        ObjectRepository.fetchArchivedObjectNames(forceRefresh: true),
      ]);

      if (!mounted) return;

      setState(() {
        archivedEmployees = result[0] as List<Employee>;
        archivedObjects = result[1] as List<String>;
        selectedEmployeeIds.removeWhere(
          (id) => !archivedEmployees.any((employee) => employee.id == id),
        );
        selectedObjectNames.removeWhere(
          (name) => !archivedObjects.contains(name),
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
    final result = archivedEmployees.where((employee) {
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
    final result = archivedObjects
        .where((name) => query.isEmpty || name.toLowerCase().contains(query))
        .toList();
    result.sort();
    return result;
  }

  int get selectedCount => kind == _ArchiveKind.employees
      ? selectedEmployeeIds.length
      : selectedObjectNames.length;

  void clearSelection() {
    selectedEmployeeIds.clear();
    selectedObjectNames.clear();
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

  void selectAllVisible(bool selected) {
    setState(() {
      if (kind == _ArchiveKind.employees) {
        final ids = visibleEmployees()
            .map((employee) => employee.id?.trim() ?? '')
            .where((id) => id.isNotEmpty);
        selected
            ? selectedEmployeeIds.addAll(ids)
            : selectedEmployeeIds.removeAll(ids);
      } else {
        final names = visibleObjects();
        selected
            ? selectedObjectNames.addAll(names)
            : selectedObjectNames.removeAll(names);
      }
    });
  }

  Future<bool> confirm({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async {
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
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF9D3E38),
                  )
                : null,
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
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF9D3E38),
              ),
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

  Future<void> restoreSelected() async {
    if (selectedCount == 0 || isBusy) return;
    final confirmed = await confirm(
      title: 'Восстановить выбранное?',
      message: kind == _ArchiveKind.employees
          ? 'Сотрудники вернутся в рабочий список в раздел «Уволенные».'
          : 'Объекты снова появятся в приложении.',
      action: 'Восстановить',
    );
    if (!confirmed || !mounted) return;

    setState(() => isBusy = true);
    try {
      if (kind == _ArchiveKind.employees) {
        for (final id in selectedEmployeeIds.toList()) {
          await EmployeeArchiveRepository.restoreEmployee(id);
        }
      } else {
        for (final name in selectedObjectNames.toList()) {
          await ObjectRepository.restoreObject(name: name);
        }
      }

      clearSelection();
      await loadData(loader: false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Выбранное восстановлено')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка восстановления: $error')));
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  Future<void> deleteSelectedForever() async {
    if (selectedCount == 0 || isBusy) return;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка удаления: $error')));
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
        TextField(
          controller: searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: kind == _ArchiveKind.employees
                ? 'Поиск в архиве сотрудников'
                : 'Поиск в архиве объектов',
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
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: allVisibleSelected,
          onChanged: isBusy ? null : (value) => selectAllVisible(value == true),
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

  Widget buildContent() {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 70),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorText != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 50),
        child: Column(
          children: [
            Text(errorText!, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    final items = kind == _ArchiveKind.employees
        ? visibleEmployees()
        : visibleObjects();

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 70),
        child: Center(
          child: Text(
            'Архив пуст',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    if (kind == _ArchiveKind.employees) {
      return Column(
        children: visibleEmployees().map((employee) {
          final id = employee.id?.trim() ?? '';
          return CheckboxListTile(
            value: selectedEmployeeIds.contains(id),
            onChanged: id.isEmpty || isBusy
                ? null
                : (value) {
                    setState(() {
                      value == true
                          ? selectedEmployeeIds.add(id)
                          : selectedEmployeeIds.remove(id);
                    });
                  },
            title: Text(
              employee.name,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              [
                employee.position,
                employee.objectName,
                employee.phone,
              ].where((value) => value.trim().isNotEmpty).join(' • '),
            ),
            secondary: const Icon(Icons.inventory_2_outlined),
            controlAffinity: ListTileControlAffinity.leading,
          );
        }).toList(),
      );
    }

    return Column(
      children: visibleObjects().map((name) {
        return CheckboxListTile(
          value: selectedObjectNames.contains(name),
          onChanged: isBusy
              ? null
              : (value) {
                  setState(() {
                    value == true
                        ? selectedObjectNames.add(name)
                        : selectedObjectNames.remove(name);
                  });
                },
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: const Text('Объект находится в архиве'),
          secondary: const Icon(Icons.inventory_2_outlined),
          controlAffinity: ListTileControlAffinity.leading,
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.profile.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Архив доступен только администратору')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Архив и удаление')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: buildTopPanel(),
                  ),
                  const SizedBox(height: 14),
                  buildContent(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 8, 18, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: selectedCount == 0 || isBusy
                    ? null
                    : restoreSelected,
                icon: const Icon(Icons.restore),
                label: const Text('Восстановить'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF9D3E38),
                ),
                onPressed: selectedCount == 0 || isBusy
                    ? null
                    : deleteSelectedForever,
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Удалить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
