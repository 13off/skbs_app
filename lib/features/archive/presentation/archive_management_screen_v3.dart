import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';

import '../../../data/employee_archive_repository.dart';
import '../../../data/object_repository.dart';
import '../../../data/permanent_deletion_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../models/employee.dart';
import '../../../widgets/premium_ui_v2.dart';

Color get _archiveText => AppAdaptivePalette.textPrimary;
Color get _archiveMuted => AppAdaptivePalette.textMuted;
Color get _archiveSoft => AppAdaptivePalette.surfaceSoft;
Color get _archiveLine => AppAdaptivePalette.border;

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
              SizedBox(height: 14),
              const Text(
                'Введите УДАЛИТЬ',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 8),
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
              icon: Icon(Icons.delete_forever_outlined),
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
    return PremiumWorkCard(
      radius: 28,
      child: Column(
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
          SizedBox(height: 14),
          TextField(
            controller: searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: kind == _ArchiveKind.employees
                  ? 'Поиск в архиве сотрудников'
                  : 'Поиск в архиве объектов',
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
            ),
          ),
          SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: _archiveSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _archiveLine),
            ),
            child: CheckboxListTile(
              value: allVisibleSelected,
              onChanged: isBusy
                  ? null
                  : (value) => selectAllVisible(value == true),
              title: const Text(
                'Выбрать все',
                style: TextStyle(
                  color: _archiveText,
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: Text(
                'Выбрано: $selectedCount',
                style: TextStyle(
                  color: _archiveMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildArchiveTile({
    required bool value,
    required ValueChanged<bool?>? onChanged,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumWorkCard(
        radius: 22,
        padding: EdgeInsets.zero,
        child: CheckboxListTile(
          value: value,
          onChanged: onChanged,
          title: Text(
            title,
            style: TextStyle(color: _archiveText, fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: _archiveMuted,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
          secondary: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _archiveSoft,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _archiveLine),
            ),
            child: Icon(icon, color: _archiveText, size: 21),
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ),
    );
  }

  Widget buildContent() {
    if (isLoading) {
      return const PremiumWorkCard(
        radius: 24,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (errorText != null) {
      return PremiumWorkCard(
        radius: 24,
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Color(0xFF9D3E38),
              size: 32,
            ),
            SizedBox(height: 10),
            Text(
              errorText!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _archiveMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 14),
            FilledButton.icon(
              onPressed: loadData,
              icon: Icon(Icons.refresh_rounded),
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
      return const PremiumWorkCard(
        radius: 24,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 34),
          child: Column(
            children: [
              Icon(Icons.inventory_2_outlined, color: _archiveMuted, size: 34),
              SizedBox(height: 10),
              Text(
                'Архив пуст',
                style: TextStyle(
                  color: _archiveText,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Здесь появятся архивированные сотрудники или объекты.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _archiveMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (kind == _ArchiveKind.employees) {
      return Column(
        children: visibleEmployees().map((employee) {
          final id = employee.id?.trim() ?? '';

          return buildArchiveTile(
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
            title: employee.name,
            subtitle: [
              employee.position,
              employee.objectName,
              employee.phone,
            ].where((value) => value.trim().isNotEmpty).join(' • '),
            icon: Icons.person_outline_rounded,
          );
        }).toList(),
      );
    }

    return Column(
      children: visibleObjects().map((name) {
        return buildArchiveTile(
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
          title: name,
          subtitle: 'Объект находится в архиве',
          icon: Icons.apartment_outlined,
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.profile.isAdmin) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: PremiumWorkBackdrop(
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: PremiumWorkCard(
                  radius: 28,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        color: _archiveMuted,
                        size: 34,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Архив доступен только администратору',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _archiveText,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Архив и удаление'),
        backgroundColor: AppAdaptivePalette.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: PremiumWorkBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildTopPanel(),
                    SizedBox(height: 14),
                    if (isBusy) ...[
                      const LinearProgressIndicator(),
                      SizedBox(height: 12),
                    ],
                    buildContent(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Material(
        color: AppAdaptivePalette.surface,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(18, 10, 18, 16),
          child: Align(
            alignment: Alignment.center,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: selectedCount == 0 || isBusy
                            ? null
                            : restoreSelected,
                        icon: Icon(Icons.restore_rounded),
                        label: const Text('Восстановить'),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF9D3E38),
                        ),
                        onPressed: selectedCount == 0 || isBusy
                            ? null
                            : deleteSelectedForever,
                        icon: Icon(Icons.delete_forever_outlined),
                        label: const Text('Удалить'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
