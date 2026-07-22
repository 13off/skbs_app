import 'package:flutter/material.dart';

import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/data_governance_repository.dart';
import '../models/data_governance.dart';

enum _GovernanceSection { trash, audit }

class DataGovernanceScreen extends StatefulWidget {
  const DataGovernanceScreen({super.key});

  @override
  State<DataGovernanceScreen> createState() => _DataGovernanceScreenState();
}

class _DataGovernanceScreenState extends State<DataGovernanceScreen> {
  static const String allObjects = '__all_objects__';
  static const String allEntities = '__all_entities__';

  final searchController = TextEditingController();

  DataGovernanceCenter? center;
  _GovernanceSection section = _GovernanceSection.trash;
  String selectedObject = allObjects;
  String selectedEntity = allEntities;
  String? busyKey;
  String? errorText;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> load({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        loading = true;
        errorText = null;
      });
    }
    try {
      final value = await DataGovernanceRepository.fetchCenter(
        objectId: selectedObject == allObjects ? null : selectedObject,
      );
      if (!mounted) return;
      setState(() {
        center = value;
        loading = false;
        errorText = null;
        if (selectedObject != allObjects &&
            !value.objects.any((object) => object.id == selectedObject)) {
          selectedObject = allObjects;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = cleanError(error);
      });
    }
  }

  String cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> selectObject(String? value) async {
    if (value == null || value == selectedObject || busyKey != null) return;
    setState(() => selectedObject = value);
    await load();
  }

  Future<void> restore(DataGovernanceTrashEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Восстановить: ${entry.title}?'),
        content: Text(
          'Запись вернётся в рабочий раздел. Связанные данные, которые хранятся отдельно, останутся на месте.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.restore_rounded),
            label: const Text('Восстановить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final key = '${entry.entityType}:${entry.entityId}';
    setState(() {
      busyKey = key;
      errorText = null;
    });
    try {
      await DataGovernanceRepository.restore(
        entityType: entry.entityType,
        entityId: entry.entityId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${entry.typeTitle}: запись восстановлена')),
      );
      await load(showLoader: false);
    } catch (error) {
      if (mounted) setState(() => errorText = cleanError(error));
    } finally {
      if (mounted) setState(() => busyKey = null);
    }
  }

  List<DataGovernanceTrashEntry> visibleTrash() {
    final value = center;
    if (value == null) return const <DataGovernanceTrashEntry>[];
    final query = searchController.text.trim().toLowerCase();
    return value.trash.where((entry) {
      if (selectedEntity != allEntities &&
          normalizeEntityType(entry.entityType) != selectedEntity) {
        return false;
      }
      if (query.isEmpty) return true;
      return <String>[
        entry.title,
        entry.subtitle,
        entry.objectName,
        entry.deleteReason,
        entry.deletedByName,
        entry.typeTitle,
      ].join(' ').toLowerCase().contains(query);
    }).toList();
  }

  List<DataGovernanceAuditEntry> visibleAudit() {
    final value = center;
    if (value == null) return const <DataGovernanceAuditEntry>[];
    final query = searchController.text.trim().toLowerCase();
    return value.audit.where((entry) {
      if (selectedEntity != allEntities &&
          normalizeEntityType(entry.entityType) != selectedEntity) {
        return false;
      }
      if (query.isEmpty) return true;
      return <String>[
        entry.typeTitle,
        entry.action,
        entry.semanticAction,
        entry.actorName,
        entry.objectName,
        entry.entityId,
      ].join(' ').toLowerCase().contains(query);
    }).toList();
  }

  String normalizeEntityType(String value) {
    return switch (value) {
      'tasks' => 'task',
      'employees' => 'employee',
      'objects' => 'object',
      'payments' => 'payment',
      'project_milestones' => 'milestone',
      'legal_documents' => 'legal_document',
      _ => value,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Контроль данных',
      subtitle: 'Общая корзина и журнал действий по рабочим модулям',
      headerTrailing: IconButton(
        tooltip: 'Обновить',
        onPressed: loading || busyKey != null ? null : load,
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          : center == null
          ? _ErrorState(message: errorText ?? 'Контроль недоступен', retry: load)
          : buildContent(),
    );
  }

  Widget buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildExplanation(),
        const SizedBox(height: 14),
        buildFilters(),
        if (errorText != null) ...[
          const SizedBox(height: 12),
          buildError(errorText!),
        ],
        const SizedBox(height: 16),
        if (section == _GovernanceSection.trash)
          buildTrash()
        else
          buildAudit(),
      ],
    );
  }

  Widget buildExplanation() {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Безопасное управление данными',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Задачи, табель, выплаты и цели удаляются мягко. Сотрудники, объекты и документы используют архив. Восстановление выполняется из одного раздела, а изменения фиксируются в журнале.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildFilters() {
    final value = center!;
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          SegmentedButton<_GovernanceSection>(
            segments: const [
              ButtonSegment<_GovernanceSection>(
                value: _GovernanceSection.trash,
                icon: Icon(Icons.delete_outline_rounded),
                label: Text('Корзина'),
              ),
              ButtonSegment<_GovernanceSection>(
                value: _GovernanceSection.audit,
                icon: Icon(Icons.manage_history_rounded),
                label: Text('Журнал'),
              ),
            ],
            selected: <_GovernanceSection>{section},
            onSelectionChanged: busyKey != null
                ? null
                : (selection) => setState(() => section = selection.first),
          ),
          const SizedBox(height: 13),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final objectField = DropdownButtonFormField<String>(
                value: selectedObject,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Объект',
                  prefixIcon: Icon(Icons.apartment_rounded),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: allObjects,
                    child: Text('Все объекты'),
                  ),
                  ...value.objects.map(
                    (object) => DropdownMenuItem<String>(
                      value: object.id,
                      child: Text(
                        object.isActive ? object.name : '${object.name} · архив',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: selectObject,
              );
              final typeField = DropdownButtonFormField<String>(
                value: selectedEntity,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Раздел',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: const [
                  DropdownMenuItem<String>(
                    value: allEntities,
                    child: Text('Все разделы'),
                  ),
                  DropdownMenuItem<String>(value: 'task', child: Text('Задачи')),
                  DropdownMenuItem<String>(value: 'attendance', child: Text('Табель')),
                  DropdownMenuItem<String>(value: 'payment', child: Text('Выплаты')),
                  DropdownMenuItem<String>(value: 'employee', child: Text('Сотрудники')),
                  DropdownMenuItem<String>(value: 'object', child: Text('Объекты')),
                  DropdownMenuItem<String>(value: 'milestone', child: Text('Цели и этапы')),
                  DropdownMenuItem<String>(value: 'legal_document', child: Text('Документы')),
                ],
                onChanged: busyKey != null
                    ? null
                    : (next) {
                        if (next != null) setState(() => selectedEntity = next);
                      },
              );

              if (wide) {
                return Row(
                  children: [
                    Expanded(child: objectField),
                    const SizedBox(width: 12),
                    Expanded(child: typeField),
                  ],
                );
              }
              return Column(
                children: [
                  objectField,
                  const SizedBox(height: 12),
                  typeField,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: section == _GovernanceSection.trash
                  ? 'Поиск в корзине'
                  : 'Поиск в журнале',
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
      ),
    );
  }

  Widget buildTrash() {
    final items = visibleTrash();
    if (items.isEmpty) {
      return const _EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Корзина пуста',
        subtitle: 'Удалённые и архивные записи появятся здесь.',
      );
    }

    return Column(
      children: items.map((entry) {
        final key = '${entry.entityType}:${entry.entityId}';
        final busy = busyKey == key;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PremiumWorkCard(
            radius: 22,
            padding: const EdgeInsets.all(15),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 650;
                final details = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      child: Icon(entityIcon(entry.entityType), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            <String>[
                              entry.typeTitle,
                              if (entry.subtitle.isNotEmpty) entry.subtitle,
                              if (entry.objectName.isNotEmpty) entry.objectName,
                            ].join(' • '),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            <String>[
                              formatDate(entry.deletedAt),
                              if (entry.deletedByName.isNotEmpty) entry.deletedByName,
                              if (entry.deleteReason.isNotEmpty) entry.deleteReason,
                            ].join(' • '),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final action = FilledButton.tonalIcon(
                  onPressed: busyKey == null ? () => restore(entry) : null,
                  icon: busy
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restore_rounded, size: 18),
                  label: const Text('Восстановить'),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      details,
                      const SizedBox(height: 13),
                      action,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: details),
                    const SizedBox(width: 16),
                    action,
                  ],
                );
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget buildAudit() {
    final items = visibleAudit();
    if (items.isEmpty) {
      return const _EmptyState(
        icon: Icons.manage_history_outlined,
        title: 'Записей пока нет',
        subtitle: 'Новые действия будут фиксироваться автоматически.',
      );
    }

    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: items.map((entry) {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            leading: CircleAvatar(
              child: Icon(actionIcon(entry.semanticAction), size: 19),
            ),
            title: Text(
              '${entry.typeTitle}: ${actionTitle(entry.semanticAction)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              <String>[
                if (entry.objectName.isNotEmpty) entry.objectName,
                entry.actorName.isEmpty ? 'Пользователь' : entry.actorName,
                formatDate(entry.createdAt),
              ].join(' • '),
            ),
            trailing: IconButton(
              tooltip: 'Подробности',
              onPressed: () => showAuditDetails(entry),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> showAuditDetails(DataGovernanceAuditEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${entry.typeTitle}: ${actionTitle(entry.semanticAction)}',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _DetailLine(label: 'Пользователь', value: entry.actorName.isEmpty ? 'Не указан' : entry.actorName),
              _DetailLine(label: 'Дата', value: formatDate(entry.createdAt)),
              if (entry.objectName.isNotEmpty)
                _DetailLine(label: 'Объект', value: entry.objectName),
              _DetailLine(label: 'Тип записи', value: entry.entityType),
              _DetailLine(label: 'ID записи', value: entry.entityId),
              if (entry.metadata.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Изменённые поля: ${entry.metadata.keys.where((key) => !key.startsWith('_')).join(', ')}',
                  style: TextStyle(
                    color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget buildError(String message) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onErrorContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  IconData entityIcon(String value) {
    return switch (normalizeEntityType(value)) {
      'task' => Icons.task_alt_rounded,
      'attendance' => Icons.calendar_month_rounded,
      'payment' => Icons.payments_outlined,
      'employee' => Icons.person_outline_rounded,
      'object' => Icons.apartment_rounded,
      'milestone' => Icons.flag_outlined,
      'legal_document' => Icons.description_outlined,
      _ => Icons.inventory_2_outlined,
    };
  }

  IconData actionIcon(String value) {
    return switch (value) {
      'created' => Icons.add_rounded,
      'restored' => Icons.restore_rounded,
      'archived' => Icons.archive_outlined,
      'deleted' => Icons.delete_outline_rounded,
      _ => Icons.edit_outlined,
    };
  }

  String actionTitle(String value) {
    return switch (value) {
      'created' => 'создано',
      'restored' => 'восстановлено',
      'archived' => 'перемещено в архив',
      'deleted' => 'удалено',
      'updated' => 'изменено',
      'task_restored' => 'задача восстановлена',
      'task_deleted' => 'задача в корзине',
      _ => value.isEmpty ? 'изменено' : value,
    };
  }

  String formatDate(DateTime? value) {
    if (value == null) return 'Дата не указана';
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 46),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback retry;

  const _ErrorState({required this.message, required this.retry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 44),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}
