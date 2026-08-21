import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../screens/adaptive_employees_screen.dart';
import '../../../screens/adaptive_timesheet_screen.dart';
import '../../../screens/period_timesheet_screen.dart';
import '../../../screens/tasks_screen.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../../accounting/presentation/adaptive_accounting_reports_screen.dart';
import '../../dispatcher/presentation/dispatcher_summary_details_screen.dart';
import '../../legal/presentation/legal_weekly_report_screen.dart';
import '../../recruitment/presentation/recruitment_applications_screen.dart';
import '../../recruitment/presentation/recruitment_dashboard_screen.dart';
import '../data/manager_reports_repository.dart';
import 'manager_report_formatters.dart';
import 'manager_report_tile.dart';
import '../../../navigation/app_page_route.dart';

class ManagerReportSections extends StatelessWidget {
  final AppUserProfile profile;
  final ManagerReportsCenter center;
  final bool onlyProblems;
  final void Function(Widget screen) onOpen;

  const ManagerReportSections({
    super.key,
    required this.profile,
    required this.center,
    required this.onlyProblems,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final objectName = center.selectedObject?.name;
    final metrics = center.metrics;
    final attendance = metrics.attendance;
    final employees = metrics.employees;
    final tasks = metrics.tasks;
    final payments = metrics.payments;
    final recruitment = metrics.recruitment;
    final legal = metrics.legal;
    final milestones = metrics.milestones;
    final legalProblems = legal.overdue + legal.highRisk;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Все отчёты',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        _DispatcherReports(
          center: center,
          onlyProblems: onlyProblems,
          onOpen: onOpen,
        ),
        _ReportSection(
          onlyProblems: onlyProblems,
          icon: Icons.calendar_month_outlined,
          title: 'Табель и посещаемость',
          subtitle: 'Смены и отсутствовавшие сотрудники за выбранный день',
          meta: attendance.missing > 0
              ? '${attendance.missing} отсутствовали'
              : '${attendance.marked} отмечено',
          problemCount: attendance.missing,
          metrics: [
            _ReportMetric(label: 'Активных', value: '${attendance.active}'),
            _ReportMetric(label: 'Отмечено', value: '${attendance.marked}'),
            _ReportMetric(
              label: 'Отсутствовали',
              value: '${attendance.missing}',
            ),
            _ReportMetric(
              label: 'Смен',
              value: attendance.shifts.toStringAsFixed(1),
            ),
          ],
          details: center.detailItems('missing_attendance'),
          onOpen: () => onOpen(
            AdaptiveTimesheetScreen(
              profile: profile,
              selectedObjectName: objectName,
            ),
          ),
          openLabel: 'Открыть табель',
          onSecondary: () =>
              onOpen(PeriodTimesheetScreen(selectedObjectName: objectName)),
          secondaryLabel: 'Отчёт за период',
        ),
        _ReportSection(
          onlyProblems: onlyProblems,
          icon: Icons.groups_outlined,
          title: 'Сотрудники',
          subtitle: 'Численность и изменения состава',
          meta: '${employees.active} активных',
          problemCount: 0,
          metrics: [
            _ReportMetric(label: 'Активных', value: '${employees.active}'),
            _ReportMetric(label: 'Добавлено', value: '${employees.added}'),
            _ReportMetric(label: 'Выбыло', value: '${employees.archived}'),
          ],
          onOpen: () => onOpen(
            AdaptiveEmployeesScreen(
              profile: profile,
              selectedObjectName: objectName,
            ),
          ),
          openLabel: 'Открыть сотрудников',
        ),
        _ReportSection(
          onlyProblems: onlyProblems,
          icon: Icons.assignment_outlined,
          title: 'Задачи и выполнение',
          subtitle: 'Результат и незакрытые работы',
          meta: tasks.problem + tasks.pending > 0
              ? '${tasks.problem + tasks.pending} требуют внимания'
              : '${tasks.done} выполнено',
          problemCount: tasks.problem + tasks.pending,
          metrics: [
            _ReportMetric(label: 'Всего', value: '${tasks.total}'),
            _ReportMetric(label: 'Выполнено', value: '${tasks.done}'),
            _ReportMetric(label: 'Незакрыто', value: '${tasks.pending}'),
            _ReportMetric(label: 'С проблемой', value: '${tasks.problem}'),
            _ReportMetric(
              label: 'Выполнение',
              value: managerReportPercent(center.trend.tasksDoneRate),
            ),
          ],
          details: center.detailItems('pending_tasks'),
          onOpen: () => onOpen(
            TasksScreen(profile: profile, selectedObjectName: objectName),
          ),
          openLabel: 'Открыть задачи',
        ),
        _ReportSection(
          onlyProblems: onlyProblems,
          icon: Icons.payments_outlined,
          title: 'Выплаты и бухгалтерия',
          subtitle: 'Операции, суммы и подтверждения',
          meta: payments.monthMissingReceipts > 0
              ? '${payments.monthMissingReceipts} без чеков'
              : '${payments.monthCount} операций за месяц',
          problemCount: payments.monthMissingReceipts,
          metrics: [
            _ReportMetric(
              label: 'Операций за месяц',
              value: '${payments.monthCount}',
            ),
            _ReportMetric(
              label: 'Сумма за месяц',
              value: managerReportMoney(payments.monthAmount),
            ),
            _ReportMetric(
              label: 'Операций за день',
              value: '${payments.dayCount}',
            ),
            _ReportMetric(
              label: 'Без чеков',
              value: '${payments.monthMissingReceipts}',
            ),
          ],
          details: center.detailItems('missing_receipts'),
          onOpen: () => onOpen(const AdaptiveAccountingReportsScreen()),
          openLabel: 'Открыть бухгалтерию',
        ),
        _ReportSection(
          onlyProblems: onlyProblems,
          icon: Icons.person_search_outlined,
          title: 'Подбор и HR',
          subtitle: 'Кандидаты и входящие обращения',
          meta:
              '${recruitment.newCount} новых · '
              '${recruitment.incomingMessages} входящих',
          problemCount: 0,
          metrics: [
            _ReportMetric(
              label: 'Активных кандидатов',
              value: '${recruitment.active}',
            ),
            _ReportMetric(label: 'Новых', value: '${recruitment.newCount}'),
            _ReportMetric(
              label: 'Входящих',
              value: '${recruitment.incomingMessages}',
            ),
          ],
          onOpen: () => onOpen(
            RecruitmentDashboardScreen(
              profile: profile,
              onOpenApplications: () =>
                  onOpen(RecruitmentApplicationsScreen(profile: profile)),
            ),
          ),
          openLabel: 'Открыть HR',
        ),
        _ReportSection(
          onlyProblems: onlyProblems,
          icon: Icons.gavel_outlined,
          title: 'Юридическое',
          subtitle: 'Риски, просрочки и документы',
          meta: legalProblems > 0
              ? '$legalProblems требуют внимания'
              : '${legal.open} открытых вопросов',
          problemCount: legalProblems,
          metrics: [
            _ReportMetric(label: 'Открыто', value: '${legal.open}'),
            _ReportMetric(label: 'Просрочено', value: '${legal.overdue}'),
            _ReportMetric(label: 'Высокий риск', value: '${legal.highRisk}'),
            _ReportMetric(
              label: 'Истекают документы',
              value: '${legal.expiringDocuments}',
            ),
          ],
          details: center.detailItems('legal_attention'),
          onOpen: () => onOpen(const LegalWeeklyReportScreen()),
          openLabel: 'Открыть юридическое',
        ),
        _ReportSection(
          onlyProblems: onlyProblems,
          icon: Icons.flag_outlined,
          title: 'Объекты и этапы',
          subtitle: 'Сроки и фактический прогресс',
          meta: milestones.overdue > 0
              ? '${milestones.overdue} просрочено'
              : '${milestones.open} открытых этапов',
          problemCount: milestones.overdue,
          metrics: [
            _ReportMetric(label: 'Открыто', value: '${milestones.open}'),
            _ReportMetric(label: 'Просрочено', value: '${milestones.overdue}'),
            _ReportMetric(
              label: 'Срок до 7 дней',
              value: '${milestones.upcoming}',
            ),
          ],
          details: center.detailItems('milestones_attention'),
        ),
      ],
    );
  }
}

class _ReportMetric extends StatelessWidget {
  final String label;
  final String value;

  const _ReportMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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

class _ReportSection extends StatelessWidget {
  final bool onlyProblems;
  final IconData icon;
  final String title;
  final String subtitle;
  final String meta;
  final List<_ReportMetric> metrics;
  final int problemCount;
  final List<ManagerReportDetailItem> details;
  final VoidCallback? onOpen;
  final String openLabel;
  final VoidCallback? onSecondary;
  final String? secondaryLabel;

  const _ReportSection({
    required this.onlyProblems,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.metrics,
    required this.problemCount,
    this.details = const <ManagerReportDetailItem>[],
    this.onOpen,
    this.openLabel = 'Открыть раздел',
    this.onSecondary,
    this.secondaryLabel,
  });

  void openSummary(BuildContext context) {
    Navigator.of(context).push<void>(
      AppPageRoute<void>(
        builder: (_) => _ManagerReportSectionScreen(
          icon: icon,
          title: title,
          subtitle: subtitle,
          metrics: metrics,
          problemCount: problemCount,
          details: details,
          onOpen: onOpen,
          openLabel: openLabel,
          onSecondary: onSecondary,
          secondaryLabel: secondaryLabel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (onlyProblems && problemCount == 0) return const SizedBox.shrink();
    return ManagerReportTile(
      icon: icon,
      title: title,
      meta: meta,
      trailingLabel: problemCount > 0 ? '$problemCount' : null,
      onTap: () => openSummary(context),
    );
  }
}

class _ManagerReportSectionScreen extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<_ReportMetric> metrics;
  final int problemCount;
  final List<ManagerReportDetailItem> details;
  final VoidCallback? onOpen;
  final String openLabel;
  final VoidCallback? onSecondary;
  final String? secondaryLabel;

  const _ManagerReportSectionScreen({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.metrics,
    required this.problemCount,
    required this.details,
    required this.onOpen,
    required this.openLabel,
    required this.onSecondary,
    required this.secondaryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppPage(
      title: title,
      subtitle: subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumWorkCard(
            radius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: scheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        problemCount > 0
                            ? 'Требует внимания: $problemCount'
                            : 'Актуальная сводка',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                if (onOpen != null || onSecondary != null) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (onOpen != null)
                        FilledButton.icon(
                          onPressed: onOpen,
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: Text(openLabel),
                        ),
                      if (onSecondary != null && secondaryLabel != null)
                        OutlinedButton.icon(
                          onPressed: onSecondary,
                          icon: const Icon(Icons.summarize_outlined),
                          label: Text(secondaryLabel!),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Ключевые показатели',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: metrics),
          const SizedBox(height: 18),
          Text(
            'Подробности',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          PremiumWorkCard(
            radius: 24,
            padding: const EdgeInsets.all(16),
            child: details.isEmpty
                ? Text(
                    'Дополнительных записей нет.',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : _ReportDetailItems(items: details),
          ),
        ],
      ),
    );
  }
}

class _ReportDetailItems extends StatelessWidget {
  final List<ManagerReportDetailItem> items;

  const _ReportDetailItems({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              child: Text('${index + 1}'),
            ),
            title: Text(
              items[index].title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (items[index].subtitle.isNotEmpty)
                  Text(items[index].subtitle),
                if (items[index].note.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    items[index].note,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (index != items.length - 1) const Divider(height: 8),
        ],
      ],
    );
  }
}

class _DispatcherReports extends StatelessWidget {
  final ManagerReportsCenter center;
  final bool onlyProblems;
  final void Function(Widget screen) onOpen;

  const _DispatcherReports({
    required this.center,
    required this.onlyProblems,
    required this.onOpen,
  });

  List<ManagerDispatcherRun> filteredRuns() {
    final runs = center.dispatcherRuns.take(12).toList();
    if (onlyProblems) {
      runs.removeWhere((run) {
        final critical =
            int.tryParse(
              (run.body.contains('отклонений')
                      ? RegExp(
                          r'(\d+) отклонений',
                        ).firstMatch(run.body)?.group(1)
                      : null) ??
                  '',
            ) ??
            0;
        return run.status == 'sent' && critical == 0;
      });
    }
    return runs;
  }

  @override
  Widget build(BuildContext context) {
    final runs = filteredRuns();
    final latest = runs.isEmpty ? null : runs.first;
    final meta = latest == null
        ? 'Сводок пока нет'
        : '${runs.length} сводок · '
              '${latest.summaryDate == null ? 'без даты' : managerReportDateText(latest.summaryDate!)}';

    return ManagerReportTile(
      icon: Icons.auto_awesome_outlined,
      title: 'Оперативные сводки',
      meta: meta,
      onTap: () {
        Navigator.of(context).push<void>(
          AppPageRoute<void>(
            builder: (_) =>
                _DispatcherReportsScreen(runs: runs, onOpen: onOpen),
          ),
        );
      },
    );
  }
}

class _DispatcherReportsScreen extends StatelessWidget {
  final List<ManagerDispatcherRun> runs;
  final void Function(Widget screen) onOpen;

  const _DispatcherReportsScreen({required this.runs, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Оперативные сводки',
      child: runs.isEmpty
          ? const PremiumWorkCard(
              radius: 24,
              padding: EdgeInsets.all(18),
              child: Text('Сводок по выбранному фильтру пока нет.'),
            )
          : PremiumWorkCard(
              radius: 24,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var index = 0; index < runs.length; index++) ...[
                    _DispatcherRunTile(run: runs[index], onOpen: onOpen),
                    if (index != runs.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
    );
  }
}

class _DispatcherRunTile extends StatelessWidget {
  final ManagerDispatcherRun run;
  final void Function(Widget screen) onOpen;

  const _DispatcherRunTile({required this.run, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Text(
        run.title.trim().isEmpty ? 'Сводка · ${run.objectName}' : run.title,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        '${run.summaryDate == null ? 'Без даты' : managerReportDateText(run.summaryDate!)} '
        '· ${managerReportRunStatus(run.status)}',
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            run.body.trim().isEmpty
                ? run.errorText.trim().isEmpty
                      ? 'Отчёт ещё не сформирован.'
                      : run.errorText
                : run.body,
            style: const TextStyle(height: 1.4, fontWeight: FontWeight.w600),
          ),
        ),
        if (run.id.isNotEmpty && run.status == 'sent') ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () =>
                  onOpen(DispatcherSummaryDetailsScreen(runId: run.id)),
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Разобрать по пунктам'),
            ),
          ),
        ],
      ],
    );
  }
}
