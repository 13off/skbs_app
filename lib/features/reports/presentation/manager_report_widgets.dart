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

class ManagerReportFilters extends StatelessWidget {
  final ManagerReportsCenter center;
  final String? selectedObjectId;
  final DateTime reportDate;
  final bool onlyProblems;
  final ValueChanged<String?> onObjectChanged;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final VoidCallback onChooseDate;
  final ValueChanged<bool> onOnlyProblemsChanged;

  const ManagerReportFilters({
    super.key,
    required this.center,
    required this.selectedObjectId,
    required this.reportDate,
    required this.onlyProblems,
    required this.onObjectChanged,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onChooseDate,
    required this.onOnlyProblemsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final objectName = center.selectedObject?.name ?? 'Все объекты';
    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final objectField = DropdownButtonFormField<String>(
                key: ValueKey<String?>(selectedObjectId),
                initialValue: selectedObjectId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Объект отчёта',
                  prefixIcon: Icon(Icons.apartment_outlined),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('Все объекты'),
                  ),
                  ...center.objects.map(
                    (object) => DropdownMenuItem<String>(
                      value: object.id,
                      child: Text(
                        object.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: onObjectChanged,
              );
              final dateField = Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Предыдущий день',
                    onPressed: onPreviousDay,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onChooseDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(managerReportDateText(reportDate)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Следующий день',
                    onPressed: onNextDay,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              );
              if (wide) {
                return Row(
                  children: [
                    Expanded(flex: 3, child: objectField),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: dateField),
                  ],
                );
              }
              return Column(
                children: [
                  objectField,
                  const SizedBox(height: 12),
                  dateField,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: onlyProblems,
            onChanged: onOnlyProblemsChanged,
            title: const Text(
              'Только проблемные разделы',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              'Сейчас: $objectName · ${managerReportDateText(reportDate)}',
            ),
          ),
        ],
      ),
    );
  }
}

class ManagerReportOverview extends StatelessWidget {
  final ManagerReportsCenter center;

  const ManagerReportOverview({super.key, required this.center});

  @override
  Widget build(BuildContext context) {
    final critical = center.criticalCount;
    final objectName = center.selectedObject?.name ?? 'Все объекты';
    return PremiumWorkCard(
      radius: 28,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  critical > 0
                      ? Icons.warning_amber_rounded
                      : Icons.verified_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      critical > 0
                          ? 'Требует внимания: $critical'
                          : 'Отклонений не найдено',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$objectName · ${managerReportDateText(center.reportDate)}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final line in ManagerReportAnalysis.lines(center)) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Icon(Icons.circle, size: 6),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    line,
                    style: const TextStyle(
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

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
    final tasksPending = center.metric('tasks', 'pending');
    final attendanceMissing = center.metric('attendance', 'missing');
    final missingReceipts = center.metric('payments', 'missing_receipts');
    final legalProblems = center.metric('legal', 'overdue') +
        center.metric('legal', 'high_risk');
    final milestoneProblems = center.metric('milestones', 'overdue');

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
          problemCount: attendanceMissing,
          metrics: [
            _ReportMetric(
              label: 'Активных',
              value: '${center.metric('attendance', 'active')}',
            ),
            _ReportMetric(
              label: 'Отмечено',
              value: '${center.metric('attendance', 'marked')}',
            ),
            _ReportMetric(label: 'Без отметки', value: '$attendanceMissing'),
            _ReportMetric(
              label: 'Смен',
              value: center
                  .decimalMetric('attendance', 'shifts')
                  .toStringAsFixed(1),
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
            _ReportMetric(
              label: 'Активных',
              value: '${center.metric('employees', 'active')}',
            ),
            _ReportMetric(
              label: 'Добавлено',
              value: '${center.metric('employees', 'added')}',
            ),
            _ReportMetric(
              label: 'Выбыло',
              value: '${center.metric('employees', 'archived')}',
            ),
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
          problemCount: center.metric('tasks', 'problem') + tasksPending,
          metrics: [
            _ReportMetric(
              label: 'Всего',
              value: '${center.metric('tasks', 'total')}',
            ),
            _ReportMetric(
              label: 'Выполнено',
              value: '${center.metric('tasks', 'done')}',
            ),
            _ReportMetric(label: 'Незакрыто', value: '$tasksPending'),
            _ReportMetric(
              label: 'С проблемой',
              value: '${center.metric('tasks', 'problem')}',
            ),
            _ReportMetric(
              label: 'Выполнение',
              value: managerReportPercent(
                center.trendValue('tasks_done_rate'),
              ),
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
          problemCount: missingReceipts,
          metrics: [
            _ReportMetric(
              label: 'Операций за месяц',
              value: '${center.metric('payments', 'month_count')}',
            ),
            _ReportMetric(
              label: 'Сумма за месяц',
              value: managerReportMoney(
                center.decimalMetric('payments', 'month_amount'),
              ),
            ),
            _ReportMetric(
              label: 'Операций за день',
              value: '${center.metric('payments', 'day_count')}',
            ),
            _ReportMetric(label: 'Без чеков', value: '$missingReceipts'),
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
              value: '${center.metric('recruitment', 'active')}',
            ),
            _ReportMetric(
              label: 'Новых',
              value: '${center.metric('recruitment', 'new')}',
            ),
            _ReportMetric(
              label: 'Входящих',
              value: '${center.metric('recruitment', 'incoming_messages')}',
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
            _ReportMetric(
              label: 'Открыто',
              value: '${center.metric('legal', 'open')}',
            ),
            _ReportMetric(
              label: 'Просрочено',
              value: '${center.metric('legal', 'overdue')}',
            ),
            _ReportMetric(
              label: 'Высокий риск',
              value: '${center.metric('legal', 'high_risk')}',
            ),
            _ReportMetric(
              label: 'Истекают документы',
              value: '${center.metric('legal', 'expiring_documents')}',
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
          problemCount: milestoneProblems,
          metrics: [
            _ReportMetric(
              label: 'Открыто',
              value: '${center.metric('milestones', 'open')}',
            ),
            _ReportMetric(
              label: 'Просрочено',
              value: '${center.metric('milestones', 'overdue')}',
            ),
            _ReportMetric(
              label: 'Срок до 7 дней',
              value: '${center.metric('milestones', 'upcoming')}',
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
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('Подробных отклонений в этом разделе нет.'),
      );
    }
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
