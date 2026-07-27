import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../widgets/app_page.dart';
import '../data/task_governance_repository.dart';
import '../models/task_governance.dart';

class TaskGovernanceScreen extends StatefulWidget {
  const TaskGovernanceScreen({super.key});

  @override
  State<TaskGovernanceScreen> createState() => _TaskGovernanceScreenState();
}

class _TaskGovernanceScreenState extends State<TaskGovernanceScreen> {
  static const String allObjects = '__all__';

  final TextEditingController searchController = TextEditingController();
  TaskGovernanceCenter? center;
  String selectedObjectId = allObjects;
  bool loading = true;
  String? errorText;
  String? restoringTaskId;

  @override
  void initState() {
    super.initState();
    searchController.addListener(_refreshSearch);
    load();
  }

  @override
  void dispose() {
    searchController
      ..removeListener(_refreshSearch)
      ..dispose();
    super.dispose();
  }

  void _refreshSearch() => setState(() {});

  Future<void> load() async {
    setState(() {
      loading = true;
      errorText = null;
    });
    try {
      final value = await TaskGovernanceRepository.fetchCenter(
        objectId: selectedObjectId == allObjects ? null : selectedObjectId,
      );
      if (!mounted) return;
      setState(() {
        center = value;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> selectObject(String? value) async {
    final next = value ?? allObjects;
    if (next == selectedObjectId) return;
    setState(() => selectedObjectId = next);
    await load();
  }

  Future<void> restore(DeletedTaskEntry task) async {
    if (restoringTaskId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Восстановить задачу?'),
        content: Text(
          'Задача «${task.work}» вернётся в рабочий список вместе с исполнителями, фотографиями и привязкой к цели.',
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

    setState(() {
      restoringTaskId = task.id;
      errorText = null;
    });
    try {
      await TaskGovernanceRepository.restoreTask(task.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Задача восстановлена')),
      );
      await load();
    } catch (error) {
      if (!mounted) return;
      setState(
        () => errorText = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => restoringTaskId = null);
    }
  }

  bool matchesSearch({
    required String objectName,
    required String work,
    required String axes,
    required String actorName,
    required String action,
  }) {
    final query = searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return <String>[objectName, work, axes, actorName, action]
        .join(' ')
        .toLowerCase()
        .contains(query);
  }

  List<DeletedTaskEntry> get visibleTrash {
    final value = center;
    if (value == null) return const <DeletedTaskEntry>[];
    return value.trash
        .where(
          (item) => matchesSearch(
            objectName: item.objectName,
            work: item.work,
            axes: item.axes,
            actorName: item.deletedByName,
            action: item.deleteReason,
          ),
        )
        .toList(growable: false);
  }

  List<TaskActionAuditEntry> get visibleAudit {
    final value = center;
    if (value == null) return const <TaskActionAuditEntry>[];
    return value.audit
        .where(
          (item) => matchesSearch(
            objectName: item.objectName,
            work: item.afterValue['work']?.toString() ??
                item.beforeValue['work']?.toString() ??
                '',
            axes: item.afterValue['axes']?.toString() ??
                item.beforeValue['axes']?.toString() ??
                '',
            actorName: item.actorName,
            action: actionTitle(item.action),
          ),
        )
        .toList(growable: false);
  }

  String formatDate(DateTime? value, {bool withTime = true}) {
    if (value == null) return '—';
    return DateFormat(withTime ? 'dd.MM.yyyy HH:mm' : 'dd.MM.yyyy').format(value);
  }

  String actionTitle(String action) {
    return switch (action) {
      'created' => 'Задача создана',
      'updated' => 'Задача изменена',
      'status_changed' => 'Статус изменён',
      'photo_added' => 'Добавлено фото',
      'photo_removed' => 'Удалено фото',
      'photo_updated' => 'Фото изменено',
      'assignee_added' => 'Добавлен исполнитель',
      'assignee_removed' => 'Удалён исполнитель',
      'goal_linked' => 'Привязана к цели',
      'goal_unlinked' => 'Отвязана от цели',
      'goal_updated' => 'Связь с целью изменена',
      'archived' => 'Перемещена в корзину',
      'restored' => 'Восстановлена',
      _ => action,
    };
  }

  IconData actionIcon(String action) {
    return switch (action) {
      'created' => Icons.add_task_rounded,
      'updated' => Icons.edit_note_rounded,
      'status_changed' => Icons.sync_alt_rounded,
      'photo_added' => Icons.add_a_photo_rounded,
      'photo_removed' => Icons.hide_image_rounded,
      'photo_updated' => Icons.photo_filter_rounded,
      'assignee_added' => Icons.person_add_alt_1_rounded,
      'assignee_removed' => Icons.person_remove_alt_1_rounded,
      'goal_linked' || 'goal_updated' => Icons.flag_rounded,
      'goal_unlinked' => Icons.outlined_flag_rounded,
      'archived' => Icons.delete_outline_rounded,
      'restored' => Icons.restore_rounded,
      _ => Icons.history_rounded,
    };
  }

  Color actionColor(String action) {
    return switch (action) {
      'archived' || 'photo_removed' || 'assignee_removed' =>
        AppAdaptivePalette.danger,
      'restored' || 'created' => AppAdaptivePalette.success,
      'status_changed' => AppAdaptivePalette.warning,
      _ => AppAdaptivePalette.accent,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Контроль задач',
      subtitle: 'Журнал действий и безопасное восстановление удалённых задач',
      headerTrailing: IconButton(
        tooltip: 'Обновить',
        onPressed: loading ? null : load,
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: loading && center == null
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFilters(),
                if (errorText != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(message: errorText!, retry: load),
                ],
                const SizedBox(height: 16),
                _buildSafetySummary(),
                const SizedBox(height: 16),
                _buildTrash(),
                const SizedBox(height: 16),
                _buildAudit(),
              ],
            ),
    );
  }

  Widget _buildFilters() {
    final objects = center?.objects ?? const <TaskGovernanceObject>[];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 720;
            final objectPicker = DropdownButtonFormField<String>(
              initialValue: selectedObjectId,
              decoration: const InputDecoration(
                labelText: 'Объект',
                prefixIcon: Icon(Icons.apartment_rounded),
              ),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem(
                  value: allObjects,
                  child: Text('Все объекты'),
                ),
                ...objects.map(
                  (object) => DropdownMenuItem(
                    value: object.id,
                    child: Text(
                      object.isActive ? object.name : '${object.name} · архив',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: loading ? null : selectObject,
            );
            final search = TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'Поиск',
                hintText: 'Работа, оси, сотрудник или действие',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            );
            if (horizontal) {
              return Row(
                children: [
                  Expanded(child: objectPicker),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: search),
                ],
              );
            }
            return Column(
              children: [
                objectPicker,
                const SizedBox(height: 12),
                search,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSafetySummary() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_rounded, color: AppAdaptivePalette.success),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Безвозвратное удаление отключено',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'При удалении задача перемещается в корзину. Исполнители, фотографии и связь с целью сохраняются. Восстановление доступно администратору и разработчику.',
                    style: TextStyle(height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrash() {
    final items = visibleTrash;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              icon: Icons.delete_outline_rounded,
              title: 'Корзина задач',
              count: items.length,
              color: AppAdaptivePalette.danger,
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const _EmptyState(
                icon: Icons.delete_sweep_outlined,
                text: 'В корзине нет задач',
              )
            else
              ...items.map(_trashTile),
          ],
        ),
      ),
    );
  }

  Widget _trashTile(DeletedTaskEntry task) {
    final isRestoring = restoringTaskId == task.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppAdaptivePalette.surfaceSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppAdaptivePalette.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      task.work.isEmpty ? 'Задача без названия' : task.work,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.tonalIcon(
                    onPressed: restoringTaskId == null ? () => restore(task) : null,
                    icon: isRestoring
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.restore_rounded),
                    label: const Text('Вернуть'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('${task.objectName} · ${task.axes} · ${formatDate(task.taskDate, withTime: false)}'),
              const SizedBox(height: 5),
              Text(
                'Удалил: ${task.deletedByName.isEmpty ? 'неизвестно' : task.deletedByName} · ${formatDate(task.deletedAt)}',
                style: TextStyle(color: AppAdaptivePalette.textMuted),
              ),
              if (task.deleteReason.trim().isNotEmpty) ...[
                const SizedBox(height: 5),
                Text('Причина: ${task.deleteReason}'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudit() {
    final items = visibleAudit;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              icon: Icons.manage_history_rounded,
              title: 'Журнал действий',
              count: items.length,
              color: AppAdaptivePalette.accent,
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const _EmptyState(
                icon: Icons.history_toggle_off_rounded,
                text: 'Действий пока нет',
              )
            else
              ...items.map(_auditTile),
          ],
        ),
      ),
    );
  }

  Widget _auditTile(TaskActionAuditEntry entry) {
    final title = actionTitle(entry.action);
    final work = entry.afterValue['work']?.toString() ??
        entry.beforeValue['work']?.toString() ??
        '';
    final details = <String>[
      if (entry.objectName.isNotEmpty) entry.objectName,
      if (work.isNotEmpty) work,
      if (entry.taskDate != null) formatDate(entry.taskDate, withTime: false),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        leading: CircleAvatar(
          backgroundColor: actionColor(entry.action).withValues(alpha: 0.14),
          foregroundColor: actionColor(entry.action),
          child: Icon(actionIcon(entry.action), size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(
          <String>[
            details,
            '${entry.actorName.isEmpty ? 'Система' : entry.actorName} · ${formatDate(entry.createdAt)}',
          ].where((value) => value.isNotEmpty).join('\n'),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _auditDetails(entry),
              style: TextStyle(color: AppAdaptivePalette.textMuted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  String _auditDetails(TaskActionAuditEntry entry) {
    if (entry.action == 'status_changed') {
      final oldStatus = entry.metadata['old_status']?.toString() ?? '—';
      final newStatus = entry.metadata['new_status']?.toString() ?? '—';
      return 'Статус: $oldStatus → $newStatus';
    }
    if (entry.action == 'archived') {
      final reason = entry.metadata['reason']?.toString().trim() ?? '';
      return reason.isEmpty ? 'Задача перемещена в корзину' : 'Причина: $reason';
    }
    if (entry.action.startsWith('photo_')) {
      final stage = entry.metadata['photo_stage']?.toString() ??
          entry.metadata['new_stage']?.toString() ??
          '';
      final name = entry.metadata['original_name']?.toString() ?? '';
      return <String>[
        if (stage.isNotEmpty) 'Этап: ${stage == 'before' ? 'До' : 'После'}',
        if (name.isNotEmpty) 'Файл: $name',
      ].join('\n');
    }
    if (entry.action.startsWith('assignee_')) {
      return 'Изменён состав исполнителей задачи';
    }
    if (entry.action.startsWith('goal_')) {
      return 'Изменена связь задачи с целью и этапом';
    }
    return 'Изменения сохранены в защищённом журнале.';
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
        Chip(label: Text('$count')),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AppAdaptivePalette.textFaint),
          const SizedBox(height: 9),
          Text(text, style: TextStyle(color: AppAdaptivePalette.textMuted)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback retry;

  const _ErrorBanner({required this.message, required this.retry});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppAdaptivePalette.danger.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppAdaptivePalette.danger),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
            TextButton(onPressed: retry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}
