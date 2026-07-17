import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../data/app_state.dart';
import '../../../data/task_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../models/task_item_data.dart';
import '../../../screens/add_task_screen.dart';
import '../../../screens/task_details_screen.dart';
import '../../../widgets/premium_ui.dart';
import '../data/milestone_repository.dart';
import '../models/milestone_models.dart';

class MilestoneDetailScreen extends StatefulWidget {
  final AppUserProfile profile;
  final String milestoneId;
  final String objectName;

  const MilestoneDetailScreen({
    super.key,
    required this.profile,
    required this.milestoneId,
    required this.objectName,
  });

  @override
  State<MilestoneDetailScreen> createState() => _MilestoneDetailScreenState();
}

class _MilestoneDetailScreenState extends State<MilestoneDetailScreen> {
  late Future<ProjectMilestone> future;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<ProjectMilestone> load() async {
    final rows = await MilestoneRepository.fetchMilestones(
      objectName: widget.objectName,
    );
    return rows.firstWhere(
      (item) => item.id == widget.milestoneId,
      orElse: () => throw Exception('Ключевой этап не найден'),
    );
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  String date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  Color itemColor(MilestoneChecklistItem item) {
    if (item.isBlocked) return const Color(0xFF9A403A);
    if (item.isEffectivelyDone) return const Color(0xFF2E7D52);
    if (item.completionFraction > 0) return const Color(0xFF9A6816);
    return const Color(0xFF6B7075);
  }

  Future<void> setItemState(
    MilestoneChecklistItem item,
    String state,
  ) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await MilestoneRepository.updateChecklistState(
        itemId: item.id,
        state: state,
      );
      await refresh();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> addChecklistItem(ProjectMilestone milestone) async {
    final titleController = TextEditingController();
    var weight = 10.0;
    var critical = false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Новый пункт готовности'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Что должно быть готово',
                    hintText: 'Например: лаборатория подтверждена',
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text('Вес'),
                    Expanded(
                      child: Slider(
                        min: 5,
                        max: 50,
                        divisions: 9,
                        label: '${weight.round()}%',
                        value: weight,
                        onChanged: (value) {
                          setDialogState(() => weight = value);
                        },
                      ),
                    ),
                    Text('${weight.round()}%'),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: critical,
                  onChanged: (value) {
                    setDialogState(() => critical = value);
                  },
                  title: const Text('Критичный пункт'),
                  subtitle: const Text(
                    'Без него этап не считается готовым к выполнению',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
    final title = titleController.text.trim();
    titleController.dispose();
    if (accepted != true || title.isEmpty) return;

    await MilestoneRepository.addChecklistItem(
      milestoneId: milestone.id,
      title: title,
      weight: weight.round(),
      isCritical: critical,
      sortOrder: milestone.items.length,
    );
    if (mounted) await refresh();
  }

  Future<void> addTask(
    ProjectMilestone milestone,
    MilestoneChecklistItem item,
  ) async {
    final initialDate = widget.profile.isForeman
        ? AppState.today
        : milestone.targetDate;
    final draft = await Navigator.push<TaskCreateDraft>(
      context,
      CupertinoPageRoute<TaskCreateDraft>(
        builder: (_) => AddTaskScreen(
          initialDate: initialDate,
          objectName: milestone.objectName,
          initialMilestoneId: milestone.id,
          initialChecklistItemId: item.id,
        ),
      ),
    );
    if (draft == null) return;

    setState(() => busy = true);
    try {
      final task = await TaskRepository.addTaskWithDetails(
        draft.task,
        objectName: milestone.objectName,
        assigneeIds: draft.assigneeIds,
        photos: draft.photos,
      );
      final taskId = task.id;
      if (taskId == null || taskId.isEmpty) {
        throw Exception('Не удалось получить ID созданной задачи');
      }
      await MilestoneRepository.linkTask(
        taskId: taskId,
        milestoneId: milestone.id,
        checklistItemId: item.id,
      );
      await refresh();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openTask(
    ProjectMilestone milestone,
    MilestoneTaskData linkedTask,
  ) async {
    final task = TaskItemData(
      linkedTask.axes,
      linkedTask.work,
      linkedTask.status,
      linkedTask.date,
      id: linkedTask.taskId,
      objectName: milestone.objectName,
    );
    final result = await Navigator.push<dynamic>(
      context,
      CupertinoPageRoute<dynamic>(
        builder: (_) => TaskDetailsScreen(task: task, profile: widget.profile),
      ),
    );
    if (result == 'delete') {
      await TaskRepository.deleteTask(task);
    } else if (result is TaskItemData) {
      await TaskRepository.updateTask(result);
    }
    if (mounted) await refresh();
  }

  Future<void> updateMilestoneStatus(
    ProjectMilestone milestone,
    String status,
  ) async {
    await MilestoneRepository.updateMilestoneStatus(
      milestoneId: milestone.id,
      status: status,
    );
    if (mounted) await refresh();
  }

  Future<void> deleteMilestone(ProjectMilestone milestone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить ключевой этап?'),
        content: const Text(
          'Чек-лист и связи с задачами будут удалены. Сами задачи останутся.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await MilestoneRepository.deleteMilestone(milestone.id);
    if (mounted) Navigator.pop(context);
  }

  Widget header(ProjectMilestone milestone) {
    final blockers = milestone.blockingItems;
    return PremiumWorkCard(
      radius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      milestone.title,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      milestone.location.trim().isEmpty
                          ? milestone.objectName
                          : '${milestone.objectName} · ${milestone.location}',
                      style: const TextStyle(
                        color: Color(0xFF6B7075),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Статус этапа',
                onSelected: (value) => updateMilestoneStatus(milestone, value),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'planned', child: Text('Запланировано')),
                  PopupMenuItem(value: 'preparing', child: Text('Подготовка')),
                  PopupMenuItem(
                    value: 'ready',
                    child: Text('Готово к выполнению'),
                  ),
                  PopupMenuItem(value: 'completed', child: Text('Выполнено')),
                  PopupMenuItem(value: 'postponed', child: Text('Перенесено')),
                ],
                child: _StatusPill(label: milestone.statusTitle),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: milestone.progress,
                    minHeight: 14,
                    backgroundColor: const Color(0xFFE5E7EA),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '${milestone.progressPercent}%',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Дата: ${date(milestone.targetDate)} · '
            'пункты ${milestone.doneItems}/${milestone.items.length} · '
            'задачи ${milestone.doneTaskCount}/${milestone.linkedTaskCount}',
            style: const TextStyle(
              color: Color(0xFF6B7075),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (blockers.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF2D29A)),
              ),
              child: Text(
                'Этап ещё не готов: ${blockers.map((item) => item.title).join(', ')}',
                style: const TextStyle(
                  color: Color(0xFF7A4E08),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          if (milestone.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(milestone.notes),
          ],
        ],
      ),
    );
  }

  Widget checklistItem(
    ProjectMilestone milestone,
    MilestoneChecklistItem item,
  ) {
    final accent = itemColor(item);
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  item.isBlocked
                      ? Icons.block_rounded
                      : item.isEffectivelyDone
                          ? Icons.check_rounded
                          : Icons.pending_actions_outlined,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (item.isCritical)
                          const _StatusPill(
                            label: 'Критично',
                            color: Color(0xFF9A403A),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.stateTitle} · вес ${item.weight}% · '
                      'задачи ${item.doneTaskCount}/${item.tasks.length}',
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                enabled: !busy,
                tooltip: 'Изменить состояние',
                onSelected: (value) => setItemState(item, value),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'not_started', child: Text('Не начато')),
                  PopupMenuItem(value: 'in_progress', child: Text('В работе')),
                  PopupMenuItem(value: 'done', child: Text('Готово')),
                  PopupMenuItem(value: 'blocked', child: Text('Заблокировано')),
                ],
              ),
            ],
          ),
          if (item.tasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...item.tasks.map(
              (task) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  task.isDone
                      ? Icons.task_alt_rounded
                      : Icons.assignment_outlined,
                  color: task.isDone
                      ? const Color(0xFF2E7D52)
                      : const Color(0xFF6B7075),
                ),
                title: Text(
                  task.work,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${date(task.date)} · ${task.axes.trim().isEmpty ? 'без осей' : task.axes}',
                ),
                trailing: _StatusPill(
                  label: task.status,
                  color: task.isDone
                      ? const Color(0xFF2E7D52)
                      : const Color(0xFF6B7075),
                ),
                onTap: () => openTask(milestone, task),
              ),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : () => addTask(milestone, item),
            icon: const Icon(Icons.add_task_rounded),
            label: const Text('Добавить задачу к этому пункту'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProjectMilestone>(
      future: future,
      builder: (context, snapshot) {
        final milestone = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Готовность этапа'),
            actions: [
              IconButton(
                onPressed: refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
              if (widget.profile.isAdmin && milestone != null)
                IconButton(
                  tooltip: 'Удалить этап',
                  onPressed: () => deleteMilestone(milestone),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          body: snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData
              ? const Center(child: CircularProgressIndicator())
              : snapshot.hasError
                  ? Center(child: Text('Ошибка: ${snapshot.error}'))
                  : RefreshIndicator(
                      onRefresh: refresh,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 980),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  header(milestone!),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Чек-лист готовности',
                                          style: TextStyle(
                                            fontSize: 21,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: busy
                                            ? null
                                            : () => addChecklistItem(milestone),
                                        icon: const Icon(Icons.add_rounded),
                                        label: const Text('Добавить пункт'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (milestone.items.isEmpty)
                                    PremiumWorkCard(
                                      radius: 24,
                                      padding: const EdgeInsets.all(24),
                                      child: const Text(
                                        'Чек-лист пуст. Добавьте условия готовности этапа.',
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  else
                                    ...milestone.items.map(
                                      (item) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: checklistItem(milestone, item),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
        );
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({
    required this.label,
    this.color = const Color(0xFF6B7075),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
