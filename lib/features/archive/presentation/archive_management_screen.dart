import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../data/employee_repository.dart';
import '../../../data/object_repository.dart';
import '../../../data/permanent_deletion_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../models/construction_object.dart';
import '../../../models/employee.dart';

enum _ArchiveCategory { employees, objects }

class ArchiveManagementScreen extends StatefulWidget {
  final AppUserProfile profile;
  final bool openObjects;

  const ArchiveManagementScreen({
    super.key,
    required this.profile,
    this.openObjects = false,
  });

  @override
  State<ArchiveManagementScreen> createState() =>
      _ArchiveManagementScreenState();
}

class _ArchiveManagementScreenState extends State<ArchiveManagementScreen> {
  final searchController = TextEditingController();

  late _ArchiveCategory category;
  bool showArchived = true;
  bool isLoading = true;
  String? errorText;
  String? busyKey;

  List<Employee> employees = <Employee>[];
  List<ConstructionObject> activeObjects = <ConstructionObject>[];
  List<String> archivedObjectNames = <String>[];

  @override
  void initState() {
    super.initState();
    category = widget.openObjects
        ? _ArchiveCategory.objects
        : _ArchiveCategory.employees;
    loadData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadData({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        isLoading = true;
        errorText = null;
      });
    }

    try {
      final results = await Future.wait<dynamic>([
        EmployeeRepository.fetchEmployees(
          includeFired: true,
          forceRefresh: true,
        ),
        ObjectRepository.fetchObjects(forceRefresh: true),
        ObjectRepository.fetchArchivedObjectNames(forceRefresh: true),
      ]);

      if (!mounted) return;

      setState(() {
        employees = results[0] as List<Employee>;
        activeObjects = results[1] as List<ConstructionObject>;
        archivedObjectNames = results[2] as List<String>;
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

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String cleanError(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  Future<bool> confirmAction({
    required String title,
    required String message,
    required String actionText,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF9D3E38),
                    )
                  : null,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(actionText),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<bool> confirmPermanentDelete({
    required String title,
    required String message,
    required String confirmationPhrase,
  }) async {
    final controller = TextEditingController();
    var phraseMatches = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              icon: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFF9D3E38),
                size: 38,
              ),
              title: Text(title, textAlign: TextAlign.center),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message),
                    const SizedBox(height: 18),
                    Text(
                      'Для подтверждения введите: $confirmationPhrase',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Подтверждение',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                      onChanged: (value) {
                        final matches =
                            value.trim() == confirmationPhrase.trim();
                        if (matches == phraseMatches) return;
                        setDialogState(() => phraseMatches = matches);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Отмена'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF9D3E38),
                  ),
                  onPressed: phraseMatches
                      ? () => Navigator.pop(dialogContext, true)
                      : null,
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('Удалить навсегда'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result == true;
  }

  Future<void> setEmployeeArchived(Employee employee, bool archived) async {
    final employeeId = employee.id?.trim() ?? '';
    if (employeeId.isEmpty || busyKey != null) return;

    final confirmed = await confirmAction(
      title: archived ? 'Переместить в архив?' : 'Восстановить сотрудника?',
      message: archived
          ? '${employee.name} исчезнет из рабочего списка. Табель, выплаты, документы и личные данные сохранятся.'
          : '${employee.name} снова появится среди активных сотрудников.',
      actionText: archived ? 'В архив' : 'Восстановить',
    );
    if (!confirmed || !mounted) return;

    setState(() => busyKey = 'employee:$employeeId');

    try {
      await EmployeeRepository.setEmployeeActive(
        employeeId: employeeId,
        isActive: !archived,
      );
      await loadData(showLoader: false);
      showMessage(
        archived
            ? '${employee.name} перемещён в архив'
            : '${employee.name} восстановлен',
      );
    } catch (error) {
      showMessage(cleanError(error));
    } finally {
      if (mounted) setState(() => busyKey = null);
    }
  }

  Future<void> deleteEmployeeForever(Employee employee) async {
    final employeeId = employee.id?.trim() ?? '';
    if (employeeId.isEmpty || employee.isActive || busyKey != null) return;

    final confirmed = await confirmPermanentDelete(
      title: 'Удалить сотрудника навсегда?',
      message:
          'Будут безвозвратно удалены карточка сотрудника, табель, выплаты, чеки, документы, личные данные и комментарии. Восстановить их будет невозможно.',
      confirmationPhrase: 'УДАЛИТЬ',
    );
    if (!confirmed || !mounted) return;

    setState(() => busyKey = 'employee:$employeeId');

    try {
      final result = await PermanentDeletionRepository.deleteArchivedEmployee(
        employeeId,
      );
      await loadData(showLoader: false);
      showMessage(
        result.hasWarnings
            ? 'Сотрудник удалён. ${result.cleanupWarnings.join(' ')}'
            : '${employee.name} удалён навсегда',
      );
    } catch (error) {
      showMessage(cleanError(error));
    } finally {
      if (mounted) setState(() => busyKey = null);
    }
  }

  Future<void> setObjectArchived(String objectName, bool archived) async {
    if (busyKey != null) return;

    final confirmed = await confirmAction(
      title: archived ? 'Архивировать объект?' : 'Восстановить объект?',
      message: archived
          ? 'Объект "$objectName" исчезнет из рабочего списка. Все данные сохранятся, а сотрудники будут перемещены в архив.'
          : 'Объект "$objectName" снова станет доступен в приложении.',
      actionText: archived ? 'В архив' : 'Восстановить',
    );
    if (!confirmed || !mounted) return;

    setState(() => busyKey = 'object:$objectName');

    try {
      if (archived) {
        await ObjectRepository.archiveObject(name: objectName);
      } else {
        await ObjectRepository.restoreObject(name: objectName);
      }
      await loadData(showLoader: false);
      showMessage(
        archived
            ? 'Объект "$objectName" перемещён в архив'
            : 'Объект "$objectName" восстановлен',
      );
    } catch (error) {
      showMessage(cleanError(error));
    } finally {
      if (mounted) setState(() => busyKey = null);
    }
  }

  Future<void> deleteObjectForever(String objectName) async {
    if (busyKey != null) return;

    final confirmed = await confirmPermanentDelete(
      title: 'Удалить объект навсегда?',
      message:
          'Перед удалением скачайте все необходимые табели, отчёты по выплатам, сводки сотрудников, акты и документы объекта. После удаления будут уничтожены сотрудники этого объекта, табель, задачи, выплаты, чеки и файлы. Восстановить данные будет невозможно.',
      confirmationPhrase: objectName,
    );
    if (!confirmed || !mounted) return;

    setState(() => busyKey = 'object:$objectName');

    try {
      final result = await PermanentDeletionRepository.deleteArchivedObject(
        objectName,
      );
      await loadData(showLoader: false);
      showMessage(
        result.hasWarnings
            ? 'Объект удалён. ${result.cleanupWarnings.join(' ')}'
            : 'Объект "$objectName" удалён навсегда',
      );
    } catch (error) {
      showMessage(cleanError(error));
    } finally {
      if (mounted) setState(() => busyKey = null);
    }
  }

  List<Employee> visibleEmployees() {
    final query = searchController.text.trim().toLowerCase();

    final list = employees.where((employee) {
      if (showArchived == employee.isActive) return false;
      if (query.isEmpty) return true;

      return employee.name.toLowerCase().contains(query) ||
          employee.position.toLowerCase().contains(query) ||
          employee.phone.toLowerCase().contains(query) ||
          employee.objectName.toLowerCase().contains(query);
    }).toList();

    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  List<String> visibleObjectNames() {
    final query = searchController.text.trim().toLowerCase();
    final names = showArchived
        ? List<String>.from(archivedObjectNames)
        : activeObjects.map((object) => object.name).toList();

    names.removeWhere((name) => !name.toLowerCase().contains(query));
    names.sort();
    return names;
  }

  Widget buildTopControls() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: _CategoryButton(
                  label: 'Сотрудники',
                  icon: Icons.groups_rounded,
                  selected: category == _ArchiveCategory.employees,
                  onTap: () {
                    setState(() {
                      category = _ArchiveCategory.employees;
                      searchController.clear();
                    });
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CategoryButton(
                  label: 'Объекты',
                  icon: Icons.apartment_rounded,
                  selected: category == _ArchiveCategory.objects,
                  onTap: () {
                    setState(() {
                      category = _ArchiveCategory.objects;
                      searchController.clear();
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilterChip(
                selected: !showArchived,
                label: const Text('Активные'),
                avatar: const Icon(Icons.check_circle_outline_rounded, size: 18),
                onSelected: (_) => setState(() => showArchived = false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilterChip(
                selected: showArchived,
                label: const Text('Архив'),
                avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                onSelected: (_) => setState(() => showArchived = true),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: 'Обновить',
              onPressed: isLoading ? null : loadData,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: category == _ArchiveCategory.employees
                ? 'Поиск сотрудника'
                : 'Поиск объекта',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: searchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget buildEmployeeCard(Employee employee) {
    final employeeId = employee.id?.trim() ?? '';
    final isBusy = busyKey == 'employee:$employeeId';

    return _ArchiveCard(
      icon: employee.isActive
          ? Icons.person_rounded
          : Icons.inventory_2_outlined,
      title: employee.name,
      subtitle: [
        employee.position.trim(),
        employee.objectName.trim(),
        employee.phone.trim(),
      ].where((value) => value.isNotEmpty).join(' • '),
      actions: employee.isActive
          ? [
              FilledButton.tonalIcon(
                onPressed: isBusy
                    ? null
                    : () => setEmployeeArchived(employee, true),
                icon: isBusy
                    ? const _SmallLoader()
                    : const Icon(Icons.archive_outlined, size: 18),
                label: const Text('В архив'),
              ),
            ]
          : [
              OutlinedButton.icon(
                onPressed: isBusy
                    ? null
                    : () => setEmployeeArchived(employee, false),
                icon: const Icon(Icons.restore_rounded, size: 18),
                label: const Text('Вернуть'),
              ),
              IconButton.filledTonal(
                tooltip: 'Удалить навсегда',
                onPressed: isBusy ? null : () => deleteEmployeeForever(employee),
                icon: isBusy
                    ? const _SmallLoader()
                    : const Icon(Icons.delete_forever_outlined),
              ),
            ],
    );
  }

  Widget buildObjectCard(String objectName) {
    final isBusy = busyKey == 'object:$objectName';

    return _ArchiveCard(
      icon: showArchived
          ? Icons.inventory_2_outlined
          : Icons.apartment_rounded,
      title: objectName,
      subtitle: showArchived
          ? 'Объект находится в архиве'
          : 'Действующий объект',
      actions: showArchived
          ? [
              OutlinedButton.icon(
                onPressed: isBusy
                    ? null
                    : () => setObjectArchived(objectName, false),
                icon: const Icon(Icons.restore_rounded, size: 18),
                label: const Text('Вернуть'),
              ),
              IconButton.filledTonal(
                tooltip: 'Удалить навсегда',
                onPressed: isBusy ? null : () => deleteObjectForever(objectName),
                icon: isBusy
                    ? const _SmallLoader()
                    : const Icon(Icons.delete_forever_outlined),
              ),
            ]
          : [
              FilledButton.tonalIcon(
                onPressed: isBusy
                    ? null
                    : () => setObjectArchived(objectName, true),
                icon: isBusy
                    ? const _SmallLoader()
                    : const Icon(Icons.archive_outlined, size: 18),
                label: const Text('В архив'),
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
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 12),
            Text(errorText!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    final cards = category == _ArchiveCategory.employees
        ? visibleEmployees().map(buildEmployeeCard).toList()
        : visibleObjectNames().map(buildObjectCard).toList();

    if (cards.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 70),
        child: Column(
          children: [
            Icon(
              showArchived
                  ? Icons.inventory_2_outlined
                  : Icons.search_off_rounded,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              showArchived ? 'Архив пуст' : 'Ничего не найдено',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < cards.length; index++) ...[
          cards[index],
          if (index != cards.length - 1) const SizedBox(height: 10),
        ],
      ],
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
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 34),
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
                      border: Border.all(color: AppColors.border),
                    ),
                    child: buildTopControls(),
                  ),
                  const SizedBox(height: 14),
                  buildContent(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? Colors.white : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchiveCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> actions;

  const _ArchiveCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final info = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );

          final actionRow = Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: compact ? WrapAlignment.start : WrapAlignment.end,
            children: actions,
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [info, const SizedBox(height: 14), actionRow],
            );
          }

          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 16),
              actionRow,
            ],
          );
        },
      ),
    );
  }
}

class _SmallLoader extends StatelessWidget {
  const _SmallLoader();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 17,
      height: 17,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
