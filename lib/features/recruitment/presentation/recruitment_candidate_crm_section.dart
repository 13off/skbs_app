import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../app/app_ui_tokens.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/recruitment_crm_workspace_repository.dart';
import '../models/recruitment_crm_workspace_models.dart';
import '../models/recruitment_models.dart';

enum _CandidateCrmView { tasks, comments, activity }

class RecruitmentCandidateCrmSection extends StatefulWidget {
  final AppUserProfile profile;
  final RecruitmentApplication application;
  final VoidCallback? onChanged;

  const RecruitmentCandidateCrmSection({
    super.key,
    required this.profile,
    required this.application,
    this.onChanged,
  });

  @override
  State<RecruitmentCandidateCrmSection> createState() =>
      _RecruitmentCandidateCrmSectionState();
}

class _RecruitmentCandidateCrmSectionState
    extends State<RecruitmentCandidateCrmSection> {
  late Future<RecruitmentCandidateWorkspaceData> future;
  _CandidateCrmView view = _CandidateCrmView.tasks;
  late String responsibleUserId;
  bool assigning = false;

  @override
  void initState() {
    super.initState();
    responsibleUserId = widget.application.responsibleUserId;
    future = load();
  }

  Future<RecruitmentCandidateWorkspaceData> load() {
    return RecruitmentCrmWorkspaceRepository.fetchCandidateWorkspace(
      companyId: widget.profile.activeCompanyId,
      applicationId: widget.application.id,
    );
  }

  Future<void> refresh() async {
    final next = load();
    if (mounted) setState(() => future = next);
    await next;
  }

  void showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
  }

  String formatDateTime(DateTime? value) {
    if (value == null) return 'Без срока';
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} · $hour:$minute';
  }

  Future<void> assignResponsible(String? value) async {
    if (assigning) return;
    final nextValue = value ?? '';
    setState(() => assigning = true);
    try {
      await RecruitmentCrmWorkspaceRepository.assignResponsible(
        applicationId: widget.application.id,
        responsibleUserId: nextValue,
      );
      if (!mounted) return;
      setState(() => responsibleUserId = nextValue);
      widget.onChanged?.call();
      await refresh();
    } catch (error) {
      showError(error);
    } finally {
      if (mounted) setState(() => assigning = false);
    }
  }

  Future<void> addComment() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый комментарий'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Зафиксируйте договорённость или важную деталь',
            prefixIcon: Icon(Icons.comment_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty) return;
    try {
      await RecruitmentCrmWorkspaceRepository.addComment(
        companyId: widget.profile.activeCompanyId,
        applicationId: widget.application.id,
        body: text,
      );
      widget.onChanged?.call();
      await refresh();
    } catch (error) {
      showError(error);
    }
  }

  Future<void> editTask(
    RecruitmentCandidateWorkspaceData workspace, [
    RecruitmentCrmTask? task,
  ]) async {
    final draft = await showModalBottomSheet<_TaskDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskEditor(
        task: task,
        responsibles: workspace.responsibles,
        initialResponsibleId: task?.assignedTo.isNotEmpty == true
            ? task!.assignedTo
            : responsibleUserId,
      ),
    );
    if (draft == null) return;
    try {
      await RecruitmentCrmWorkspaceRepository.saveTask(
        id: task?.id ?? '',
        companyId: widget.profile.activeCompanyId,
        applicationId: widget.application.id,
        title: draft.title,
        description: draft.description,
        taskType: draft.taskType,
        priority: draft.priority,
        dueAt: draft.dueAt,
        assignedTo: draft.assignedTo,
      );
      widget.onChanged?.call();
      await refresh();
    } catch (error) {
      showError(error);
    }
  }

  Future<void> setTaskStatus(RecruitmentCrmTask task, String status) async {
    try {
      await RecruitmentCrmWorkspaceRepository.setTaskStatus(
        companyId: widget.profile.activeCompanyId,
        applicationId: widget.application.id,
        taskId: task.id,
        status: status,
      );
      widget.onChanged?.call();
      await refresh();
    } catch (error) {
      showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RecruitmentCandidateWorkspaceData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const PremiumWorkCard(
            padding: EdgeInsets.symmetric(vertical: 42),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return PremiumWorkCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                const Icon(Icons.error_outline_rounded, size: 34),
                const SizedBox(height: AppUi.gap8),
                Text(
                  'Не удалось загрузить CRM-карточку: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppUi.gap12),
                OutlinedButton.icon(
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Повторить'),
                ),
              ],
            ),
          );
        }

        final workspace =
            snapshot.data ?? RecruitmentCandidateWorkspaceData.empty;
        final pending = workspace.pendingTasks;
        final overdue = pending.where((task) => task.isOverdue).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PremiumWorkCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final responsible = DropdownButtonFormField<String>(
                        initialValue:
                            workspace.responsibles.any(
                              (item) => item.userId == responsibleUserId,
                            )
                            ? responsibleUserId
                            : '',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Ответственный HR',
                          prefixIcon: Icon(Icons.support_agent_rounded),
                        ),
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('Не назначен'),
                          ),
                          ...workspace.responsibles.map(
                            (item) => DropdownMenuItem<String>(
                              value: item.userId,
                              child: Text(
                                item.fullName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: assigning ? null : assignResponsible,
                      );
                      final metrics = Wrap(
                        spacing: AppUi.gap8,
                        runSpacing: AppUi.gap8,
                        children: [
                          _MetricPill(
                            icon: Icons.pending_actions_rounded,
                            label: 'Открытых дел: ${pending.length}',
                          ),
                          _MetricPill(
                            icon: Icons.warning_amber_rounded,
                            label: 'Просрочено: $overdue',
                            warning: overdue > 0,
                          ),
                          _MetricPill(
                            icon: Icons.comment_outlined,
                            label: 'Комментариев: ${workspace.comments.length}',
                          ),
                          _MetricPill(
                            icon: Icons.history_rounded,
                            label: 'Событий: ${workspace.activities.length}',
                          ),
                        ],
                      );
                      if (constraints.maxWidth < 720) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            responsible,
                            const SizedBox(height: AppUi.gap12),
                            metrics,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 320, child: responsible),
                          const SizedBox(width: AppUi.gap16),
                          Expanded(child: metrics),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppUi.gap16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<_CandidateCrmView>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: _CandidateCrmView.tasks,
                          icon: Icon(Icons.task_alt_rounded),
                          label: Text('Дела'),
                        ),
                        ButtonSegment(
                          value: _CandidateCrmView.comments,
                          icon: Icon(Icons.forum_outlined),
                          label: Text('Комментарии'),
                        ),
                        ButtonSegment(
                          value: _CandidateCrmView.activity,
                          icon: Icon(Icons.timeline_rounded),
                          label: Text('Лента событий'),
                        ),
                      ],
                      selected: {view},
                      onSelectionChanged: (selection) {
                        setState(() => view = selection.first);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppUi.gap12),
            switch (view) {
              _CandidateCrmView.tasks => _tasks(workspace),
              _CandidateCrmView.comments => _comments(workspace),
              _CandidateCrmView.activity => _activities(workspace),
            },
          ],
        );
      },
    );
  }

  Widget _tasks(RecruitmentCandidateWorkspaceData workspace) {
    final tasks = List<RecruitmentCrmTask>.from(workspace.tasks)
      ..sort((first, second) {
        if (first.isPending != second.isPending)
          return first.isPending ? -1 : 1;
        final firstDue = first.dueAt ?? DateTime(9999);
        final secondDue = second.dueAt ?? DateTime(9999);
        return firstDue.compareTo(secondDue);
      });
    return PremiumWorkCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Дела и напоминания',
                  style: TextStyle(
                    color: AppAdaptivePalette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => editTask(workspace),
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('Добавить дело'),
              ),
            ],
          ),
          const SizedBox(height: AppUi.gap12),
          if (tasks.isEmpty)
            const _EmptyWorkspaceMessage(
              icon: Icons.task_alt_rounded,
              text:
                  'Дел пока нет. Добавьте звонок, проверку документов или другое действие.',
            )
          else
            ...tasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: AppUi.gap8),
                child: _TaskCard(
                  task: task,
                  dueText: formatDateTime(task.dueAt),
                  onEdit: task.isPending
                      ? () => editTask(workspace, task)
                      : null,
                  onComplete: task.isPending
                      ? () => setTaskStatus(task, 'completed')
                      : null,
                  onReopen: !task.isPending
                      ? () => setTaskStatus(task, 'pending')
                      : null,
                  onCancel: task.isPending
                      ? () => setTaskStatus(task, 'cancelled')
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _comments(RecruitmentCandidateWorkspaceData workspace) {
    return PremiumWorkCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Комментарии HR',
                  style: TextStyle(
                    color: AppAdaptivePalette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: addComment,
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('Комментарий'),
              ),
            ],
          ),
          const SizedBox(height: AppUi.gap12),
          if (workspace.comments.isEmpty)
            const _EmptyWorkspaceMessage(
              icon: Icons.forum_outlined,
              text:
                  'Комментарии сохраняются отдельно, с автором и датой, и больше не перезаписывают друг друга.',
            )
          else
            ...workspace.comments.map(
              (comment) => Padding(
                padding: const EdgeInsets.only(bottom: AppUi.gap8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppAdaptivePalette.surfaceSoft,
                    borderRadius: BorderRadius.circular(AppUi.controlRadius),
                    border: Border.all(color: AppAdaptivePalette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_circle_outlined, size: 18),
                          const SizedBox(width: AppUi.gap8),
                          Expanded(
                            child: Text(
                              comment.authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            formatDateTime(comment.createdAt),
                            style: TextStyle(
                              color: AppAdaptivePalette.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppUi.gap8),
                      Text(comment.body, style: const TextStyle(height: 1.4)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _activities(RecruitmentCandidateWorkspaceData workspace) {
    return PremiumWorkCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Лента событий',
            style: TextStyle(
              color: AppAdaptivePalette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppUi.gap12),
          if (workspace.activities.isEmpty)
            const _EmptyWorkspaceMessage(
              icon: Icons.timeline_rounded,
              text:
                  'События появятся при изменении этапа, данных, документов, сообщений, комментариев и дел.',
            )
          else
            ...workspace.activities.map(
              (activity) => Padding(
                padding: const EdgeInsets.only(bottom: AppUi.gap8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppAdaptivePalette.accent.withValues(
                          alpha: 0.10,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _activityIcon(activity.eventType),
                        size: 18,
                        color: AppAdaptivePalette.accent,
                      ),
                    ),
                    const SizedBox(width: AppUi.gap12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: AppAdaptivePalette.surfaceSoft,
                          borderRadius: BorderRadius.circular(
                            AppUi.controlRadius,
                          ),
                          border: Border.all(color: AppAdaptivePalette.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (activity.body.isNotEmpty) ...[
                              const SizedBox(height: AppUi.gap4),
                              Text(
                                activity.body,
                                style: const TextStyle(height: 1.35),
                              ),
                            ],
                            const SizedBox(height: AppUi.gap8),
                            Text(
                              '${activity.actorName} · ${formatDateTime(activity.createdAt)}',
                              style: TextStyle(
                                color: AppAdaptivePalette.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _activityIcon(String type) {
    if (type.contains('stage')) return Icons.swap_horiz_rounded;
    if (type.contains('comment')) return Icons.comment_outlined;
    if (type.contains('task')) return Icons.task_alt_rounded;
    if (type.contains('document')) return Icons.description_outlined;
    if (type.contains('message')) return Icons.telegram;
    if (type.contains('responsible')) return Icons.support_agent_rounded;
    if (type.contains('archive')) return Icons.inventory_2_outlined;
    if (type.contains('created')) return Icons.person_add_alt_1_rounded;
    return Icons.history_rounded;
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool warning;

  const _MetricPill({
    required this.icon,
    required this.label,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = warning
        ? AppAdaptivePalette.warning
        : AppAdaptivePalette.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppUi.gap4),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final RecruitmentCrmTask task;
  final String dueText;
  final VoidCallback? onEdit;
  final VoidCallback? onComplete;
  final VoidCallback? onReopen;
  final VoidCallback? onCancel;

  const _TaskCard({
    required this.task,
    required this.dueText,
    this.onEdit,
    this.onComplete,
    this.onReopen,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = task.isOverdue
        ? AppAdaptivePalette.warning
        : task.isCompleted
        ? AppAdaptivePalette.success
        : AppAdaptivePalette.accent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surfaceSoft,
        borderRadius: BorderRadius.circular(AppUi.controlRadius),
        border: Border.all(
          color: task.isOverdue
              ? AppAdaptivePalette.warning.withValues(alpha: 0.55)
              : AppAdaptivePalette.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.task_alt_rounded, color: statusColor, size: 20),
          ),
          const SizedBox(width: AppUi.gap12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: AppUi.gap4),
                  Text(task.description, style: const TextStyle(height: 1.35)),
                ],
                const SizedBox(height: AppUi.gap8),
                Wrap(
                  spacing: AppUi.gap8,
                  runSpacing: AppUi.gap4,
                  children: [
                    _MiniPill(task.typeTitle),
                    _MiniPill(task.priorityTitle),
                    _MiniPill(
                      task.isOverdue ? 'Просрочено · $dueText' : dueText,
                    ),
                    if (task.assigneeName.isNotEmpty)
                      _MiniPill(task.assigneeName),
                    if (!task.isPending)
                      _MiniPill(task.isCompleted ? 'Выполнено' : 'Отменено'),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit?.call();
              if (value == 'complete') onComplete?.call();
              if (value == 'reopen') onReopen?.call();
              if (value == 'cancel') onCancel?.call();
            },
            itemBuilder: (_) => [
              if (onEdit != null)
                const PopupMenuItem(value: 'edit', child: Text('Изменить')),
              if (onComplete != null)
                const PopupMenuItem(
                  value: 'complete',
                  child: Text('Выполнить'),
                ),
              if (onReopen != null)
                const PopupMenuItem(
                  value: 'reopen',
                  child: Text('Вернуть в работу'),
                ),
              if (onCancel != null)
                const PopupMenuItem(value: 'cancel', child: Text('Отменить')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String text;
  const _MiniPill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppAdaptivePalette.border),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyWorkspaceMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyWorkspaceMessage({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surfaceSoft,
        borderRadius: BorderRadius.circular(AppUi.controlRadius),
        border: Border.all(color: AppAdaptivePalette.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppAdaptivePalette.textMuted),
          const SizedBox(width: AppUi.gap12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppAdaptivePalette.textMuted,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskDraft {
  final String title;
  final String description;
  final String taskType;
  final String priority;
  final DateTime? dueAt;
  final String assignedTo;

  const _TaskDraft({
    required this.title,
    required this.description,
    required this.taskType,
    required this.priority,
    required this.dueAt,
    required this.assignedTo,
  });
}

class _TaskEditor extends StatefulWidget {
  final RecruitmentCrmTask? task;
  final List<RecruitmentResponsibleOption> responsibles;
  final String initialResponsibleId;

  const _TaskEditor({
    this.task,
    required this.responsibles,
    required this.initialResponsibleId,
  });

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late final TextEditingController titleController;
  late final TextEditingController descriptionController;
  late String taskType;
  late String priority;
  late String assignedTo;
  DateTime? dueAt;
  String? error;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.task?.title ?? '');
    descriptionController = TextEditingController(
      text: widget.task?.description ?? '',
    );
    taskType = widget.task?.taskType ?? 'call';
    priority = widget.task?.priority ?? 'normal';
    assignedTo = widget.task?.assignedTo ?? widget.initialResponsibleId;
    dueAt = widget.task?.dueAt ?? DateTime.now().add(const Duration(days: 1));
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> chooseDate() async {
    final current = dueAt ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (!mounted) return;
    setState(() {
      dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? current.hour,
        time?.minute ?? current.minute,
      );
    });
  }

  String dateText() {
    if (dueAt == null) return 'Без срока';
    final value = dueAt!;
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  void submit() {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      setState(() => error = 'Введите название дела');
      return;
    }
    Navigator.pop(
      context,
      _TaskDraft(
        title: title,
        description: descriptionController.text.trim(),
        taskType: taskType,
        priority: priority,
        dueAt: dueAt,
        assignedTo: assignedTo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(
        18,
        16,
        18,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surface,
        borderRadius: BorderRadius.circular(AppUi.modalRadius),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.task == null ? 'Новое дело' : 'Изменить дело',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppUi.gap12),
            TextField(
              controller: titleController,
              autofocus: widget.task == null,
              decoration: const InputDecoration(
                labelText: 'Что нужно сделать',
                prefixIcon: Icon(Icons.task_alt_rounded),
              ),
            ),
            const SizedBox(height: AppUi.gap12),
            TextField(
              controller: descriptionController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Подробности',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: AppUi.gap12),
            DropdownButtonFormField<String>(
              initialValue: taskType,
              decoration: const InputDecoration(
                labelText: 'Тип дела',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: recruitmentCrmTaskTypes
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(recruitmentCrmTaskTypeTitle(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => taskType = value ?? 'other'),
            ),
            const SizedBox(height: AppUi.gap12),
            DropdownButtonFormField<String>(
              initialValue: priority,
              decoration: const InputDecoration(
                labelText: 'Приоритет',
                prefixIcon: Icon(Icons.priority_high_rounded),
              ),
              items: recruitmentCrmPriorities
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(recruitmentCrmPriorityTitle(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => priority = value ?? 'normal'),
            ),
            const SizedBox(height: AppUi.gap12),
            DropdownButtonFormField<String>(
              initialValue:
                  widget.responsibles.any((item) => item.userId == assignedTo)
                  ? assignedTo
                  : '',
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Исполнитель',
                prefixIcon: Icon(Icons.support_agent_rounded),
              ),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem(value: '', child: Text('Любой HR')),
                ...widget.responsibles.map(
                  (item) => DropdownMenuItem(
                    value: item.userId,
                    child: Text(item.fullName, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => assignedTo = value ?? ''),
            ),
            const SizedBox(height: AppUi.gap12),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const Icon(Icons.event_outlined),
              title: const Text('Срок'),
              subtitle: Text(dateText()),
              trailing: dueAt == null
                  ? const Icon(Icons.chevron_right_rounded)
                  : IconButton(
                      tooltip: 'Убрать срок',
                      onPressed: () => setState(() => dueAt = null),
                      icon: const Icon(Icons.close_rounded),
                    ),
              onTap: chooseDate,
            ),
            if (error != null) ...[
              const SizedBox(height: AppUi.gap8),
              Text(error!, style: TextStyle(color: AppAdaptivePalette.danger)),
            ],
            const SizedBox(height: AppUi.gap16),
            FilledButton.icon(
              onPressed: submit,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Сохранить дело'),
            ),
          ],
        ),
      ),
    );
  }
}
