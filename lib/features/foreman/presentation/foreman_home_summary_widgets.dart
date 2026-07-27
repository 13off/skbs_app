import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../data/app_state.dart';
import '../../shared/presentation/specialist_desktop_ui.dart';
import 'foreman_workspace_models.dart';

class ForemanShiftIdentity extends StatelessWidget {
  final String objectName;

  const ForemanShiftIdentity({super.key, required this.objectName});

  String dateText(DateTime date) {
    const months = <String>[
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    const weekdays = <String>[
      'понедельник',
      'вторник',
      'среда',
      'четверг',
      'пятница',
      'суббота',
      'воскресенье',
    ];
    return '${date.day} ${months[date.month - 1]} · ${weekdays[date.weekday - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: specialistLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: specialistSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: specialistLine),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      color: specialistMuted,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        objectName.isEmpty ? 'Объект не назначен' : objectName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: specialistText,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    SpecialistStatusPill(
                      label: 'Объект прораба',
                      color: specialistMuted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppAdaptivePalette.surfaceElevated,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: specialistLine),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    color: specialistMuted,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    dateText(AppState.today),
                    style: TextStyle(
                      color: specialistMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ForemanHomeMetrics extends StatelessWidget {
  final ForemanDashboardData data;
  final VoidCallback onOpenTimesheet;
  final VoidCallback onOpenTasks;

  const ForemanHomeMetrics({
    super.key,
    required this.data,
    required this.onOpenTimesheet,
    required this.onOpenTasks,
  });

  String shift(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final present = data.employees.where((employee) {
      final id = employee.id;
      return id != null && (data.shifts[id] ?? 0) > 0;
    }).length;
    final totalShifts = data.shifts.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    final done = data.todayTasks
        .where((task) => task.status == 'Выполнено')
        .length;
    final withoutPhoto = data.todayTasks.where((task) {
      return task.status == 'Выполнено' && data.metaFor(task).photoCount == 0;
    }).length;
    final withoutReport = data.overdueTasks
        .where((task) => task.notDoneComment.trim().isEmpty)
        .length;
    final attention = withoutPhoto + withoutReport;

    return Row(
      children: [
        Expanded(
          child: SpecialistMetricCard(
            icon: Icons.groups_2_outlined,
            label: 'На смене',
            value: '$present из ${data.employees.length}',
            hint: 'Сумма смен: ${shift(totalShifts)}',
            accent: specialistSuccess,
            onTap: onOpenTimesheet,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SpecialistMetricCard(
            icon: Icons.assignment_outlined,
            label: 'Выполненные задачи',
            value: '$done',
            hint: 'из ${data.todayTasks.length}',
            onTap: onOpenTasks,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SpecialistMetricCard(
            icon: Icons.history_rounded,
            label: 'Просрочено',
            value: '${data.overdueTasks.length}',
            hint: 'Не закрыты до сегодняшнего дня',
            accent: data.overdueTasks.isEmpty
                ? specialistSuccess
                : specialistDanger,
            onTap: onOpenTasks,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SpecialistMetricCard(
            icon: Icons.fact_check_outlined,
            label: 'Требуют контроля',
            value: '$attention',
            hint: 'Без фото: $withoutPhoto • без отчёта: $withoutReport',
            accent: attention == 0 ? specialistSuccess : specialistWarning,
            onTap: onOpenTasks,
          ),
        ),
      ],
    );
  }
}
