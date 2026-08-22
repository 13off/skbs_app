import 'package:flutter/material.dart';

import '../../../models/task_item_data.dart';
import '../../../widgets/responsibility_actor_line.dart';
import '../../shared/presentation/specialist_desktop_table.dart';
import '../../shared/presentation/specialist_desktop_ui.dart';
import '../data/foreman_workspace_repository.dart';

class ForemanTaskMetrics extends StatelessWidget {
  final List<TaskItemData> tasks;
  final Map<String, ForemanTaskMeta> meta;
  final String objectName;

  const ForemanTaskMetrics({
    super.key,
    required this.tasks,
    required this.meta,
    required this.objectName,
  });

  ForemanTaskMeta metaFor(TaskItemData task) {
    final id = task.id?.trim();
    return id == null || id.isEmpty
        ? const ForemanTaskMeta()
        : meta[id] ?? const ForemanTaskMeta();
  }

  @override
  Widget build(BuildContext context) {
    final done = tasks.where((task) => task.status == 'Выполнено').length;
    final withoutPhoto = tasks.where((task) {
      return task.status == 'Выполнено' && metaFor(task).photoCount == 0;
    }).length;
    final withoutReport = tasks.where((task) {
      return task.status != 'Выполнено' && task.notDoneComment.trim().isEmpty;
    }).length;

    return Row(
      children: [
        Expanded(
          child: SpecialistMetricCard(
            icon: Icons.assignment_outlined,
            label: 'Всего задач',
            value: '${tasks.length}',
            hint: objectName.isEmpty ? 'Объект не назначен' : objectName,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SpecialistMetricCard(
            icon: Icons.check_circle_outline_rounded,
            label: 'Выполнено',
            value: '$done',
            hint: tasks.isEmpty
                ? '0% от общего числа'
                : '${(done / tasks.length * 100).round()}% от общего числа',
            accent: specialistSuccess,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SpecialistMetricCard(
            icon: Icons.no_photography_outlined,
            label: 'Без фото',
            value: '$withoutPhoto',
            hint: 'Выполнены без подтверждения',
            accent: withoutPhoto == 0 ? specialistSuccess : specialistWarning,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SpecialistMetricCard(
            icon: Icons.report_problem_outlined,
            label: 'Без отчёта',
            value: '$withoutReport',
            hint: 'Не завершены без комментария',
            accent: withoutReport == 0 ? specialistSuccess : specialistWarning,
          ),
        ),
      ],
    );
  }
}

class ForemanTaskTable extends StatelessWidget {
  final List<TaskItemData> tasks;
  final Map<String, ForemanTaskMeta> meta;
  final ValueChanged<TaskItemData> onOpenTask;

  const ForemanTaskTable({
    super.key,
    required this.tasks,
    required this.meta,
    required this.onOpenTask,
  });

  ForemanTaskMeta metaFor(TaskItemData task) {
    final id = task.id?.trim();
    return id == null || id.isEmpty
        ? const ForemanTaskMeta()
        : meta[id] ?? const ForemanTaskMeta();
  }

  Color statusColor(TaskItemData task) {
    if (task.status == 'Выполнено') return specialistSuccess;
    if (task.status == 'Запланировано') return specialistMuted;
    return specialistWarning;
  }

  Widget confirmation(TaskItemData task, ForemanTaskMeta taskMeta) {
    if (task.status == 'Выполнено') {
      return SpecialistStatusPill(
        label: taskMeta.photoCount > 0
            ? 'Фото: ${taskMeta.photoCount}'
            : 'Нет фото',
        color: taskMeta.photoCount > 0 ? specialistSuccess : specialistDanger,
        icon: taskMeta.photoCount > 0
            ? Icons.photo_camera_outlined
            : Icons.no_photography_outlined,
      );
    }

    final hasReport = task.notDoneComment.trim().isNotEmpty;
    return SpecialistStatusPill(
      label: hasReport ? 'Есть отчёт' : 'Нет отчёта',
      color: hasReport ? specialistWarning : specialistDanger,
      icon: hasReport ? Icons.comment_outlined : Icons.report_problem_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SpecialistDesktopTable(
      minWidth: 1420,
      columns: const [
        SpecialistTableColumn('Статус', flex: 2),
        SpecialistTableColumn('Работа', flex: 5),
        SpecialistTableColumn('Оси / участок', flex: 2),
        SpecialistTableColumn('Исполнители', flex: 4),
        SpecialistTableColumn('Подтверждение', flex: 3),
        SpecialistTableColumn('Комментарий', flex: 4),
      ],
      rows: tasks.map((task) {
        final taskMeta = metaFor(task);
        return SpecialistTableRowData(
          onTap: () => onOpenTask(task),
          cells: [
            SpecialistStatusPill(label: task.status, color: statusColor(task)),
            _TaskWorkWithResponsibility(task: task),
            specialistCellText(
              task.axes.trim().isEmpty ? 'Не указаны' : task.axes,
              color: specialistMuted,
            ),
            specialistCellText(taskMeta.assigneeTitle, color: specialistMuted),
            confirmation(task, taskMeta),
            specialistCellText(task.notDoneComment, color: specialistMuted),
          ],
        );
      }).toList(),
    );
  }
}

class _TaskWorkWithResponsibility extends StatelessWidget {
  final TaskItemData task;

  const _TaskWorkWithResponsibility({required this.task});

  bool get sameResponsibleActor {
    final creator = task.creator;
    final editor = task.lastEditor;
    if (creator == null || editor == null) return false;

    final creatorId = creator.userId?.trim() ?? '';
    final editorId = editor.userId?.trim() ?? '';
    if (creatorId.isNotEmpty && editorId.isNotEmpty) {
      return creatorId == editorId;
    }

    final creatorName = creator.fullName.trim().toLowerCase();
    final editorName = editor.fullName.trim().toLowerCase();
    return creatorName.isNotEmpty && creatorName == editorName;
  }

  @override
  Widget build(BuildContext context) {
    final creator = task.creator;
    final editor = task.lastEditor;
    final sameActor = sameResponsibleActor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        specialistCellText(
          task.work.trim().isEmpty ? 'Работа без названия' : task.work,
          weight: FontWeight.w900,
        ),
        if (creator != null || editor != null) ...[
          const SizedBox(height: 7),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (sameActor && editor != null)
                ResponsibilityActorLine(
                  label: 'Создал и изменил',
                  actor: editor,
                  compact: true,
                )
              else ...[
                if (creator != null)
                  ResponsibilityActorLine(
                    label: 'Создал',
                    actor: creator,
                    compact: true,
                  ),
                if (editor != null)
                  ResponsibilityActorLine(
                    label: 'Изменил',
                    actor: editor,
                    compact: true,
                  ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
