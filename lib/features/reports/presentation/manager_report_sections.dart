import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../screens/adaptive_employees_screen.dart';
import '../../../screens/adaptive_timesheet_screen.dart';
import '../../../screens/period_timesheet_screen.dart';
import '../../../screens/tasks_screen.dart';
import '../../../widgets/premium_ui.dart';
import '../../accounting/presentation/adaptive_accounting_reports_screen.dart';
import '../../dispatcher/presentation/dispatcher_summary_details_screen.dart';
import '../../legal/presentation/legal_weekly_report_screen.dart';
import '../../recruitment/presentation/recruitment_applications_screen.dart';
import '../../recruitment/presentation/recruitment_dashboard_screen.dart';
import '../data/manager_reports_repository.dart';
import 'manager_report_formatters.dart';

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
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Рабочие данные собраны в одном месте. Разделы раскрываются отдельно.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _DispatcherReports(
          center: center,
          onlyProblems: onlyProblems,
          onOpen: onOpen,
        ),
        _ReportSection(
          onlyProblems: onlyProblems,
          icon: Icons.calendar_month_outlined,
          title: 'Табель и начисления',
          subtitle: 'Смены, часы, отсутствие отметок и отчёт за период',
          problemCount: attendance.missing,
          metrics: [
            _ReportMetric(label: 'Активных', value: '${attendance.active}'),
            _ReportMetric(label: 'Отмечено', value: '${attendance.marked}'),
            _ReportMetric(label: 'Без отметки', value: '${attendance.missing}'),
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
          onSecondary: () => onOpen(
            PeriodTimesheetScreen(selectedObjectName: objectName),
          ),
          secondaryLabel: 'Отчёт за период',
        ),
        _ReportSection(
          onlyProblems: onlyProblems,
          icon: Icons.groups_outlined,
          title: 'Сотрудники',
          subtitle: 'Численность, приём, выбытие и данные по людям',
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
          subtitle: 'Результат за день, проблемы и незакрытые работы',
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
            TasksScreen(
              profile: profile,
              selectedObjectName: objectName,
            ),
          ),
          openLabel: 'Открыть задачи',
        ),
        _ReportSection(
          onlyProblems: onlyProblems,
          icon: Icons.payments_outlined,
          title: 'Выплаты и бухгалтерия',
          subtitle: 'Реестр выплат, суммы, чеки и начисления',
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
          openLabel: 'Открыть бухгалтерские отчёты',
        ),
        _ReportSection(
          onlyProblems: onlyProblems,
          icon: Icons.person_search_outlined,
          title: 'Подбор и HR',
          subtitle: 'Кандидаты, новые заявки и входящие сообщения',
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
              onOpenApplications: () => onOpen(
                RecruitmentApplicationsScreen(profile: profile),
              ),
            ),
          ),
          openLabel: 'Открыть HR-сводку',
        ),
        _ReportSection(
          onlyProblems: onlyProblems,
          icon: Icons.gavel_outlined,
          title: 'Юридическое',
          subtitle: 'Открытые вопросы, риски, просрочки и документы',
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
          openLabel: 'Открыть отчёт юриста',
        ),
        _ReportSection(
          onlyProblems: onlyProblems,
          icon: Icons.flag_outlined,
          title: 'Объекты и этапы',
          subtitle: 'Открытые, просроченные и ближайшие этапы работ',
          problemCount: milestones.overdue,
          metrics: [
            _ReportMetric(label: 'Открыто', value: '${milestones.open}'),
            _ReportMetric(
              label: 'Просрочено',
              value: '${milestones.overdue}',
            ),
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
  final List<Widget> metrics;
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
    required this.metrics,
    required this.problemCount,
    this.details = const <ManagerReportDetailItem>[],
    this.onOpen,
    this.openLabel = 'Открыть подробно',
    this.onSecondary,
    this.secondaryLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (onlyProblems && problemCount == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumWorkCard(
        radius: 24,
        padding: EdgeInsets.zero,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon),
          ),
          title: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          subtitle: Text(subtitle),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (problemCount > 0)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$problemCount',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              const Icon(Icons.keyboard_arrow_down_rounded),
            ],
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(spacing: 8, runSpacing: 8, children: metrics),
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ReportDetailItems(items: details),
            ],
            if (onOpen != null || onSecondary != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onOpen != null)
                    FilledButton.tonalIcon(
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
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
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

  @override
  Widget build(BuildContext context) {
    final runs = center.dispatcherRuns.take(12).toList();
    if (onlyProblems) {
      runs.removeWhere((run) {
        final critical = int.tryParse(
              (run.body.contains('отклонений')
                      ? RegExp(r'(\d+) отклонений')
                          .firstMatch(run.body)
                          ?.group(1)
                      : null) ??
                  '',
            ) ??
            0;
        return run.status == 'sent' && critical == 0;
      });
    }

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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.auto_awesome_outlined),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Оперативные сводки',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text('История отчётов ИИ-диспетчера по объектам'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (runs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Сводок по выбранному фильтру пока нет.'),
              )
            else
              for (final run in runs)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 12),
                  title: Text(
                    run.title.trim().isEmpty
                        ? 'Сводка · ${run.objectName}'
                        : run.title,
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
                        style: const TextStyle(
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (run.id.isNotEmpty && run.status == 'sent') ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonalIcon(
                          onPressed: () => onOpen(
                            DispatcherSummaryDetailsScreen(runId: run.id),
                          ),
                          icon: const Icon(Icons.analytics_outlined),
                          label: const Text('Разобрать по пунктам'),
                        ),
                      ),
                    ],
                  ],
                ),
          ],
        ),
      ),
    );
  }
}
