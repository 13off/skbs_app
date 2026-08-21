import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../screens/adaptive_employees_screen.dart';
import '../../../screens/adaptive_timesheet_screen.dart';
import '../../../screens/tasks_screen.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../../accounting/presentation/adaptive_accounting_reports_screen.dart';
import '../../legal/presentation/legal_weekly_report_screen.dart';
import '../data/manager_reports_repository.dart';
import 'manager_report_formatters.dart';
import '../../../navigation/app_page_route.dart';

class ManagerDailyAiReviewCard extends StatelessWidget {
  final AppUserProfile profile;
  final ManagerReportsCenter center;
  final void Function(Widget screen) onOpen;

  const ManagerDailyAiReviewCard({
    super.key,
    required this.profile,
    required this.center,
    required this.onOpen,
  });

  void _open(BuildContext context) {
    Navigator.of(context).push<void>(
      AppPageRoute<void>(
        builder: (_) => ManagerDailyAiReviewScreen(
          profile: profile,
          center: center,
          onOpen: onOpen,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final metrics = center.metrics;

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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.auto_awesome_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ИИ-разбор рабочего дня',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      center.criticalCount > 0
                          ? 'Итог готов · требует внимания: ${center.criticalCount}'
                          : 'Итог готов · критичных отклонений нет',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(
                label: 'Выполнено задач',
                value: '${metrics.tasks.done}',
              ),
              _MetricChip(
                label: 'Отмечено сотрудников',
                value: '${metrics.attendance.marked}',
              ),
              const _MetricChip(label: 'Приоритетов на завтра', value: '3'),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: () => _open(context),
            icon: const Icon(Icons.summarize_outlined),
            label: const Text('Открыть разбор дня'),
          ),
        ],
      ),
    );
  }
}

class ManagerDailyAiReviewScreen extends StatelessWidget {
  final AppUserProfile profile;
  final ManagerReportsCenter center;
  final void Function(Widget screen) onOpen;

  const ManagerDailyAiReviewScreen({
    super.key,
    required this.profile,
    required this.center,
    required this.onOpen,
  });

  List<String> _completed() {
    final metrics = center.metrics;
    final lines = <String>[];
    if (metrics.tasks.done > 0) {
      lines.add(
        'Завершено ${metrics.tasks.done} из ${metrics.tasks.total} задач. '
        'Выполнение — ${managerReportPercent(center.trend.tasksDoneRate)}.',
      );
    }
    if (metrics.attendance.marked > 0) {
      lines.add(
        'Табель заполнен у ${metrics.attendance.marked} сотрудников; '
        'зафиксировано ${metrics.attendance.shifts.toStringAsFixed(1)} смен.',
      );
    }
    if (metrics.payments.dayCount > 0) {
      lines.add(
        'В реестр внесено ${metrics.payments.dayCount} выплат за день.',
      );
    }
    if (lines.isEmpty) {
      lines.add(
        'Завершённые операции за выбранный день пока не зафиксированы.',
      );
    }
    return lines;
  }

  List<String> _problems() {
    final metrics = center.metrics;
    final lines = <String>[];
    if (metrics.attendance.missing > 0) {
      lines.add('Отсутствовали ${metrics.attendance.missing} сотрудников.');
    }
    if (metrics.tasks.problem > 0) {
      lines.add('С проблемой отмечено ${metrics.tasks.problem} задач.');
    }
    if (metrics.tasks.pending > 0) {
      lines.add('Незакрытыми остаются ${metrics.tasks.pending} задач.');
    }
    if (metrics.payments.monthMissingReceipts > 0) {
      lines.add(
        'В реестре выплат отсутствуют '
        '${metrics.payments.monthMissingReceipts} подтверждающих чеков.',
      );
    }
    final legalProblems = metrics.legal.overdue + metrics.legal.highRisk;
    if (legalProblems > 0) {
      lines.add(
        'Юридических просрочек и вопросов высокого риска: $legalProblems.',
      );
    }
    if (metrics.milestones.overdue > 0) {
      lines.add('По объектам просрочено ${metrics.milestones.overdue} этапов.');
    }
    if (lines.isEmpty) {
      lines.add('Критичных проблем по данным приложения не найдено.');
    }
    return lines;
  }

  List<String> _expenses() {
    final payments = center.metrics.payments;
    return <String>[
      'Расходы за месяц — ${managerReportMoney(payments.monthAmount)}; '
          'операций в реестре: ${payments.monthCount}.',
      payments.dayMissingReceipts > 0
          ? 'За выбранный день проведено ${payments.dayCount} операций, '
                'без чеков — ${payments.dayMissingReceipts}.'
          : 'За выбранный день проведено ${payments.dayCount} операций; '
                'все имеют подтверждения.',
    ];
  }

  List<String> _employees() {
    final details = center.detailItems('missing_attendance');
    if (details.isNotEmpty) {
      return details.take(6).map((item) {
        final note = <String>[
          item.subtitle,
          item.note,
        ].where((value) => value.trim().isNotEmpty).join(' · ');
        return note.isEmpty ? item.title : '${item.title} — $note';
      }).toList();
    }
    if (center.metrics.attendance.missing > 0) {
      return <String>[
        'Отсутствовали ${center.metrics.attendance.missing} сотрудников.',
      ];
    }
    return <String>['Отсутствовавших сотрудников нет.'];
  }

  List<String> _documents() {
    final metrics = center.metrics;
    final lines = <String>[];
    if (metrics.legal.expiringDocuments > 0) {
      lines.add(
        'Подготовить продление или замену для '
        '${metrics.legal.expiringDocuments} истекающих документов.',
      );
    }
    if (metrics.payments.monthMissingReceipts > 0) {
      lines.add(
        'Собрать ${metrics.payments.monthMissingReceipts} '
        'недостающих чеков по выплатам.',
      );
    }
    for (final item in center.detailItems('legal_attention').take(4)) {
      final note = <String>[
        item.subtitle,
        item.note,
      ].where((value) => value.trim().isNotEmpty).join(' · ');
      lines.add(note.isEmpty ? item.title : '${item.title} — $note');
    }
    if (lines.isEmpty) {
      lines.add('Срочных документов на завтра не найдено.');
    }
    return lines;
  }

  List<String> _priorities() {
    final metrics = center.metrics;
    final result = <String>[];

    void add(String value) {
      if (result.length < 3) result.add(value);
    }

    if (metrics.attendance.missing > 0) {
      add('Взять объяснительные у отсутствовавших сотрудников.');
    }
    if (metrics.tasks.problem > 0) {
      add('Разобрать задачи с проблемами и назначить решения.');
    }
    if (metrics.tasks.pending > 0) {
      add('Уточнить результат и сроки незавершённых работ.');
    }
    if (metrics.payments.monthMissingReceipts > 0) {
      add('Собрать подтверждения по выплатам без чеков.');
    }
    if (metrics.legal.overdue + metrics.legal.highRisk > 0) {
      add('Проверить юридические просрочки и высокие риски.');
    }
    if (metrics.milestones.overdue > 0) {
      add('Сверить фактический прогресс просроченных этапов.');
    }

    add('Утвердить задачи, исполнителей и ожидаемый результат смены.');
    add('Проверить состав смены и готовность сотрудников.');
    add('Зафиксировать табель, выплаты, документы и статус объектов.');
    return result.take(3).toList();
  }

  Widget _actions() {
    final objectName = center.selectedObject?.name;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: () => onOpen(
            AdaptiveTimesheetScreen(
              profile: profile,
              selectedObjectName: objectName,
            ),
          ),
          icon: const Icon(Icons.calendar_month_outlined),
          label: const Text('Открыть табель'),
        ),
        OutlinedButton.icon(
          onPressed: () => onOpen(
            TasksScreen(profile: profile, selectedObjectName: objectName),
          ),
          icon: const Icon(Icons.assignment_outlined),
          label: const Text('Открыть задачи'),
        ),
        OutlinedButton.icon(
          onPressed: () => onOpen(const AdaptiveAccountingReportsScreen()),
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Открыть выплаты'),
        ),
        OutlinedButton.icon(
          onPressed: () => onOpen(
            AdaptiveEmployeesScreen(
              profile: profile,
              selectedObjectName: objectName,
            ),
          ),
          icon: const Icon(Icons.groups_outlined),
          label: const Text('Открыть сотрудников'),
        ),
        OutlinedButton.icon(
          onPressed: () => onOpen(const LegalWeeklyReportScreen()),
          icon: const Icon(Icons.gavel_outlined),
          label: const Text('Открыть юридическое'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final objectName = center.selectedObject?.name ?? 'Все объекты';
    final date = managerReportDateText(center.reportDate);

    return AppPage(
      title: 'ИИ-разбор рабочего дня',
      subtitle: '$date · $objectName',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumWorkCard(
            radius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Итог руководителя',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  'Разбор собран по актуальным данным приложения. '
                  'Он ничего не изменяет автоматически.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                _actions(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ReviewSection(
            icon: Icons.task_alt_rounded,
            title: 'Что выполнено',
            lines: _completed(),
          ),
          _ReviewSection(
            icon: Icons.warning_amber_rounded,
            title: 'Какие проблемы возникли',
            lines: _problems(),
          ),
          _ReviewSection(
            icon: Icons.payments_outlined,
            title: 'Расходы и выплаты',
            lines: _expenses(),
          ),
          _ReviewSection(
            icon: Icons.groups_outlined,
            title: 'Отсутствовали сотрудники',
            lines: _employees(),
          ),
          _ReviewSection(
            icon: Icons.description_outlined,
            title: 'Документы на завтра',
            lines: _documents(),
          ),
          _ReviewSection(
            icon: Icons.flag_outlined,
            title: 'Три приоритетные задачи на завтра',
            lines: _priorities(),
            numbered: true,
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> lines;
  final bool numbered;

  const _ReviewSection({
    required this.icon,
    required this.title,
    required this.lines,
    this.numbered = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumWorkCard(
        radius: 24,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < lines.length; index++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: scheme.surfaceContainerHighest,
                    child: Text(
                      numbered ? '${index + 1}' : '•',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        lines[index],
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (index != lines.length - 1) const Divider(height: 18),
            ],
          ],
        ),
      ),
    );
  }
}
