import 'package:flutter/material.dart';

import '../../../models/task_item_data.dart';
import '../../shared/presentation/specialist_desktop_table.dart';
import '../../shared/presentation/specialist_desktop_ui.dart';
import '../data/foreman_workspace_repository.dart';
import 'foreman_workspace_models.dart';

class ForemanTodayTasks extends StatelessWidget {
  final ForemanDashboardData data;
  final VoidCallback onOpenTasks;
  final VoidCallback onAddTask;
  final ValueChanged<TaskItemData> onOpenTask;

  const ForemanTodayTasks({
    super.key,
    required this.data,
    required this.onOpenTasks,
    required this.onAddTask,
    required this.onOpenTask,
  });

  Color statusColor(TaskItemData task) {
    if (task.status == 'Выполнено') return specialistSuccess;
    if (task.status == 'Запланировано') return specialistMuted;
    return specialistWarning;
  }

  Widget confirmation(TaskItemData task, ForemanTaskMeta meta) {
    if (task.status == 'Выполнено') {
      return SpecialistStatusPill(
        label: meta.photoCount > 0 ? 'Фото: ${meta.photoCount}' : 'Нет фото',
        color: meta.photoCount > 0 ? specialistSuccess : specialistDanger,
        icon: meta.photoCount > 0
            ? Icons.photo_camera_outlined
            : Icons.no_photography_outlined,
      );
    }

    final hasComment = task.notDoneComment.trim().isNotEmpty;
    return SpecialistStatusPill(
      label: hasComment ? 'Есть отчёт' : 'Нет отчёта',
      color: hasComment ? specialistWarning : specialistDanger,
      icon: hasComment ? Icons.comment_outlined : Icons.report_problem_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = List<TaskItemData>.from(data.todayTasks)
      ..sort((first, second) {
        final firstDone = first.status == 'Выполнено' ? 1 : 0;
        final secondDone = second.status == 'Выполнено' ? 1 : 0;
        return firstDone.compareTo(secondDone);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'План работ на сегодня',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'Статус, участок, исполнители и подтверждение результата',
                    style: TextStyle(
                      color: specialistMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onOpenTasks,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Открыть раздел'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (tasks.isEmpty)
          SpecialistMessageCard(
            icon: Icons.assignment_outlined,
            title: 'На сегодня задач нет',
            description: 'Создайте первую задачу для текущей смены.',
            actionLabel: 'Добавить задачу',
            onAction: () async => onAddTask(),
          )
        else
          SpecialistDesktopTable(
            minWidth: 1120,
            columns: const [
              SpecialistTableColumn('Статус', flex: 2),
              SpecialistTableColumn('Работа', flex: 5),
              SpecialistTableColumn('Оси / участок', flex: 2),
              SpecialistTableColumn('Исполнители', flex: 4),
              SpecialistTableColumn('Подтверждение', flex: 3),
            ],
            rows: tasks.map((task) {
              final meta = data.metaFor(task);
              return SpecialistTableRowData(
                onTap: () => onOpenTask(task),
                cells: [
                  SpecialistStatusPill(
                    label: task.status,
                    color: statusColor(task),
                  ),
                  specialistCellText(
                    task.work.trim().isEmpty ? 'Работа без названия' : task.work,
                    weight: FontWeight.w900,
                  ),
                  specialistCellText(
                    task.axes.trim().isEmpty ? 'Не указаны' : task.axes,
                    color: specialistMuted,
                  ),
                  specialistCellText(
                    meta.assigneeTitle,
                    color: specialistMuted,
                  ),
                  confirmation(task, meta),
                ],
              );
            }).toList(),
          ),
      ],
    );
  }
}

class ForemanOverdueTasks extends StatelessWidget {
  final ForemanDashboardData data;
  final ValueChanged<TaskItemData> onOpenTask;

  const ForemanOverdueTasks({
    super.key,
    required this.data,
    required this.onOpenTask,
  });

  String date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (data.overdueTasks.isEmpty) {
      return const SpecialistMessageCard(
        icon: Icons.task_alt_rounded,
        title: 'Просроченных задач нет',
        description: 'Все работы прошлых дней закрыты.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 2, 4, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Просроченные задачи',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              Text(
                'Работы прошлых дней, которые ещё не закрыты',
                style: TextStyle(
                  color: specialistMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SpecialistDesktopTable(
          minWidth: 1120,
          columns: const [
            SpecialistTableColumn('Дата', flex: 2),
            SpecialistTableColumn('Работа', flex: 5),
            SpecialistTableColumn('Оси / участок', flex: 2),
            SpecialistTableColumn('Исполнители', flex: 4),
            SpecialistTableColumn('Отчёт', flex: 3),
          ],
          rows: data.overdueTasks.map((task) {
            final meta = data.metaFor(task);
            final hasReport = task.notDoneComment.trim().isNotEmpty;
            return SpecialistTableRowData(
              onTap: () => onOpenTask(task),
              cells: [
                SpecialistStatusPill(
                  label: date(task.date),
                  color: specialistDanger,
                ),
                specialistCellText(
                  task.work.trim().isEmpty ? 'Работа без названия' : task.work,
                  weight: FontWeight.w900,
                ),
                specialistCellText(
                  task.axes.trim().isEmpty ? 'Не указаны' : task.axes,
                  color: specialistMuted,
                ),
                specialistCellText(
                  meta.assigneeTitle,
                  color: specialistMuted,
                ),
                SpecialistStatusPill(
                  label: hasReport ? 'Есть комментарий' : 'Нет отчёта',
                  color: hasReport ? specialistWarning : specialistDanger,
                  icon: hasReport
                      ? Icons.comment_outlined
                      : Icons.report_problem_outlined,
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
