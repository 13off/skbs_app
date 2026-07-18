import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../screens/adaptive_employees_screen.dart';
import '../../../screens/adaptive_timesheet_screen.dart';
import '../../../screens/period_timesheet_screen.dart';
import '../../../screens/tasks_screen.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/notification_bell.dart';
import '../../../widgets/premium_ui.dart';
import '../../accounting/presentation/adaptive_accounting_reports_screen.dart';
import '../../dispatcher/data/dispatcher_summary_repository.dart';
import '../../dispatcher/presentation/dispatcher_summary_details_screen.dart';
import '../../legal/presentation/legal_weekly_report_screen.dart';
import '../../recruitment/presentation/recruitment_applications_screen.dart';
import '../../recruitment/presentation/recruitment_dashboard_screen.dart';
import '../data/manager_reports_repository.dart';

class ManagerReportsScreen extends StatefulWidget {
  final AppUserProfile profile;
  final String? selectedObjectName;
  final ValueChanged<String?> onObjectChanged;

  const ManagerReportsScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
    required this.onObjectChanged,
  });

  @override
  State<ManagerReportsScreen> createState() => _ManagerReportsScreenState();
}

class _ManagerReportsScreenState extends State<ManagerReportsScreen> {
  late DateTime reportDate;
  late Future<ManagerReportsCenter> future;
  String? selectedObjectId;
  bool onlyProblems = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    reportDate = DateTime(now.year, now.month, now.day);
    future = loadInitial();
  }

  Future<ManagerReportsCenter> loadInitial() async {
    final initial = await ManagerReportsRepository.fetch(reportDate: reportDate);
    final requestedName = widget.selectedObjectName?.trim() ?? '';
    if (requestedName.isEmpty) return initial;

    for (final object in initial.objects) {
      if (object.name.trim().toLowerCase() == requestedName.toLowerCase()) {
        selectedObjectId = object.id;
        return ManagerReportsRepository.fetch(
          objectId: object.id,
          reportDate: reportDate,
        );
      }
    }
    return initial;
  }

  Future<void> reload() async {
    final next = ManagerReportsRepository.fetch(
      objectId: selectedObjectId,
      reportDate: reportDate,
    );
    setState(() => future = next);
    await next;
  }

  void changeDate(int days) {
    setState(() {
      reportDate = reportDate.add(Duration(days: days));
      future = ManagerReportsRepository.fetch(
        objectId: selectedObjectId,
        reportDate: reportDate,
      );
    });
  }

  Future<void> chooseDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: reportDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (value == null || !mounted) return;
    setState(() {
      reportDate = DateTime(value.year, value.month, value.day);
      future = ManagerReportsRepository.fetch(
        objectId: selectedObjectId,
        reportDate: reportDate,
      );
    });
  }

  void changeObject(ManagerReportsCenter center, String? value) {
    final nextId = value?.trim().isEmpty == true ? null : value;
    String? nextName;
    if (nextId != null) {
      for (final object in center.objects) {
        if (object.id == nextId) {
          nextName = object.name;
          break;
        }
      }
    }
    widget.onObjectChanged(nextName);
    setState(() {
      selectedObjectId = nextId;
      future = ManagerReportsRepository.fetch(
        objectId: selectedObjectId,
        reportDate: reportDate,
      );
    });
  }

  String dateText(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}.'
        '${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  String money(num value) {
    final integer = value.round().toString();
    final chunks = <String>[];
    for (var index = integer.length; index > 0; index -= 3) {
      final start = index - 3 < 0 ? 0 : index - 3;
      chunks.insert(0, integer.substring(start, index));
    }
    return '${chunks.join(' ')} ₽';
  }

  String percent(double value) {
    final rounded = value.roundToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$rounded%';
  }

  Future<void> open(Widget screen) {
    return Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(builder: (_) => screen),
    );
  }

  Widget filters(ManagerReportsCenter center) {
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
                onChanged: (value) => changeObject(center, value),
              );
              final dateField = Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Предыдущий день',
                    onPressed: () => changeDate(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: chooseDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(dateText(reportDate)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Следующий день',
                    onPressed: () => changeDate(1),
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
            onChanged: (value) => setState(() => onlyProblems = value),
            title: const Text(
              'Только проблемные разделы',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text('Сейчас: $objectName · ${dateText(reportDate)}'),
          ),
        ],
      ),
    );
  }

  List<String> analysisLines(ManagerReportsCenter center) {
    final lines = <String>[];
    final taskRate = center.trendValue('tasks_done_rate');
    final yesterdayRate = center.trendValue('tasks_yesterday_done_rate');
    final weekRate = center.trendValue('tasks_week_done_rate');
    final attendanceMissing = center.metric('attendance', 'missing');
    final yesterdayMissing = center.trendInt('attendance_missing_yesterday');
    final missingReceipts = center.metric('payments', 'missing_receipts');
    final legalAttention = center.metric('legal', 'overdue') +
        center.metric('legal', 'high_risk');
    final milestoneOverdue = center.metric('milestones', 'overdue');

    if (center.metric('tasks', 'total') == 0) {
      lines.add('На выбранную дату задачи не заведены.');
    } else if (taskRate < yesterdayRate) {
      lines.add(
        'Выполнение задач снизилось: ${percent(taskRate)} против ${percent(yesterdayRate)} вчера.',
      );
    } else if (taskRate > yesterdayRate) {
      lines.add(
        'Выполнение задач выросло: ${percent(taskRate)} против ${percent(yesterdayRate)} вчера.',
      );
    } else {
      lines.add('Выполнение задач: ${percent(taskRate)}; среднее за 7 дней — ${percent(weekRate)}.');
    }

    if (attendanceMissing == 0) {
      lines.add('Табель заполнен по всем активным сотрудникам.');
    } else {
      final direction = attendanceMissing < yesterdayMissing
          ? 'меньше, чем вчера'
          : attendanceMissing > yesterdayMissing
              ? 'больше, чем вчера'
              : 'столько же, сколько вчера';
      lines.add('Без отметки в табеле: $attendanceMissing — $direction.');
    }

    if (missingReceipts > 0) {
      lines.add('Выплаты без прикреплённых чеков: $missingReceipts.');
    }
    if (legalAttention > 0) {
      lines.add('Юридических просрочек и вопросов высокого риска: $legalAttention.');
    }
    if (milestoneOverdue > 0) {
      lines.add('Просроченных этапов объекта: $milestoneOverdue.');
    }
    if (center.criticalCount == 0) {
      lines.add('Критичных отклонений в выбранных разделах нет.');
    }
    return lines;
  }

  Widget overview(ManagerReportsCenter center) {
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
                      '$objectName · ${dateText(center.reportDate)}',
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
          for (final line in analysisLines(center)) ...[
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

  Widget metric(String label, String value) {
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

  Widget detailItems(List<ManagerReportDetailItem> items) {
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
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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

  Widget reportSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> metrics,
    required int problemCount,
    List<ManagerReportDetailItem> details = const <ManagerReportDetailItem>[],
    VoidCallback? onOpen,
    String openLabel = 'Открыть подробно',
    VoidCallback? onSecondary,
    String? secondaryLabel,
  }) {
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
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
              detailItems(details),
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
                      label: Text(secondaryLabel),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String runStatus(String status) {
    return switch (status) {
      'sent' => 'Готов',
      'processing' => 'Формируется',
      'failed' => 'Ошибка',
      'pending' => 'Ожидает',
      _ => status,
    };
  }

  Widget dispatcherReports(ManagerReportsCenter center) {
    final runs = center.dispatcherRuns.take(12).toList();
    if (onlyProblems) {
      runs.removeWhere((run) {
        final critical = int.tryParse(
              (run.body.contains('отклонений')
                      ? RegExp(r'(\d+) отклонений').firstMatch(run.body)?.group(1)
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
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
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
                    '${run.summaryDate == null ? 'Без даты' : dateText(run.summaryDate!)} · ${runStatus(run.status)}',
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
                          onPressed: () => open(
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

  Widget reportContent(ManagerReportsCenter center) {
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
        filters(center),
        const SizedBox(height: 12),
        overview(center),
        const SizedBox(height: 18),
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
        dispatcherReports(center),
        reportSection(
          icon: Icons.calendar_month_outlined,
          title: 'Табель и начисления',
          subtitle: 'Смены, часы, отсутствие отметок и отчёт за период',
          problemCount: attendanceMissing,
          metrics: [
            metric('Активных', '${center.metric('attendance', 'active')}'),
            metric('Отмечено', '${center.metric('attendance', 'marked')}'),
            metric('Без отметки', '$attendanceMissing'),
            metric('Смен', center.decimalMetric('attendance', 'shifts').toStringAsFixed(1)),
          ],
          details: center.detailItems('missing_attendance'),
          onOpen: () => open(
            AdaptiveTimesheetScreen(
              profile: widget.profile,
              selectedObjectName: objectName,
            ),
          ),
          openLabel: 'Открыть табель',
          onSecondary: () => open(
            PeriodTimesheetScreen(selectedObjectName: objectName),
          ),
          secondaryLabel: 'Отчёт за период',
        ),
        reportSection(
          icon: Icons.groups_outlined,
          title: 'Сотрудники',
          subtitle: 'Численность, приём, выбытие и данные по людям',
          problemCount: 0,
          metrics: [
            metric('Активных', '${center.metric('employees', 'active')}'),
            metric('Добавлено', '${center.metric('employees', 'added')}'),
            metric('Выбыло', '${center.metric('employees', 'archived')}'),
          ],
          onOpen: () => open(
            AdaptiveEmployeesScreen(
              profile: widget.profile,
              selectedObjectName: objectName,
            ),
          ),
          openLabel: 'Открыть сотрудников',
        ),
        reportSection(
          icon: Icons.assignment_outlined,
          title: 'Задачи и выполнение',
          subtitle: 'Результат за день, проблемы и незакрытые работы',
          problemCount: center.metric('tasks', 'problem') + tasksPending,
          metrics: [
            metric('Всего', '${center.metric('tasks', 'total')}'),
            metric('Выполнено', '${center.metric('tasks', 'done')}'),
            metric('Незакрыто', '$tasksPending'),
            metric('С проблемой', '${center.metric('tasks', 'problem')}'),
            metric('Выполнение', percent(center.trendValue('tasks_done_rate'))),
          ],
          details: center.detailItems('pending_tasks'),
          onOpen: () => open(
            TasksScreen(
              profile: widget.profile,
              selectedObjectName: objectName,
            ),
          ),
          openLabel: 'Открыть задачи',
        ),
        reportSection(
          icon: Icons.payments_outlined,
          title: 'Выплаты и бухгалтерия',
          subtitle: 'Реестр выплат, суммы, чеки и начисления',
          problemCount: missingReceipts,
          metrics: [
            metric('Операций за месяц', '${center.metric('payments', 'month_count')}'),
            metric('Сумма за месяц', money(center.decimalMetric('payments', 'month_amount'))),
            metric('Операций за день', '${center.metric('payments', 'day_count')}'),
            metric('Без чеков', '$missingReceipts'),
          ],
          details: center.detailItems('missing_receipts'),
          onOpen: () => open(const AdaptiveAccountingReportsScreen()),
          openLabel: 'Открыть бухгалтерские отчёты',
        ),
        reportSection(
          icon: Icons.person_search_outlined,
          title: 'Подбор и HR',
          subtitle: 'Кандидаты, новые заявки и входящие сообщения',
          problemCount: 0,
          metrics: [
            metric('Активных кандидатов', '${center.metric('recruitment', 'active')}'),
            metric('Новых', '${center.metric('recruitment', 'new')}'),
            metric('Входящих', '${center.metric('recruitment', 'incoming_messages')}'),
          ],
          onOpen: () => open(
            RecruitmentDashboardScreen(
              profile: widget.profile,
              onOpenApplications: () {
                open(RecruitmentApplicationsScreen(profile: widget.profile));
              },
            ),
          ),
          openLabel: 'Открыть HR-сводку',
        ),
        reportSection(
          icon: Icons.gavel_outlined,
          title: 'Юридическое',
          subtitle: 'Открытые вопросы, риски, просрочки и документы',
          problemCount: legalProblems,
          metrics: [
            metric('Открыто', '${center.metric('legal', 'open')}'),
            metric('Просрочено', '${center.metric('legal', 'overdue')}'),
            metric('Высокий риск', '${center.metric('legal', 'high_risk')}'),
            metric('Истекают документы', '${center.metric('legal', 'expiring_documents')}'),
          ],
          details: center.detailItems('legal_attention'),
          onOpen: () => open(const LegalWeeklyReportScreen()),
          openLabel: 'Открыть отчёт юриста',
        ),
        reportSection(
          icon: Icons.flag_outlined,
          title: 'Объекты и этапы',
          subtitle: 'Открытые, просроченные и ближайшие этапы работ',
          problemCount: milestoneProblems,
          metrics: [
            metric('Открыто', '${center.metric('milestones', 'open')}'),
            metric('Просрочено', '${center.metric('milestones', 'overdue')}'),
            metric('Срок до 7 дней', '${center.metric('milestones', 'upcoming')}'),
          ],
          details: center.detailItems('milestones_attention'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Отчёты',
      subtitle: 'Единый центр аналитики руководителя',
      headerTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NotificationBell(selectedObjectName: widget.selectedObjectName),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            tooltip: 'Обновить',
            onPressed: reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      child: FutureBuilder<ManagerReportsCenter>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const PremiumWorkCard(
              radius: 24,
              child: Padding(
                padding: EdgeInsets.all(36),
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          if (snapshot.hasError) {
            return PremiumWorkCard(
              radius: 24,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Не удалось загрузить отчёты',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text('${snapshot.error}'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }
          return reportContent(snapshot.data!);
        },
      ),
    );
  }
}
