import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/manager_weekly_contribution_repository.dart';
import 'manager_report_tile.dart';
import '../../../navigation/app_page_route.dart';

class ManagerWeeklyContributionSection extends StatelessWidget {
  final Future<ManagerWeeklyContributionReport> future;
  final ValueChanged<ManagerWeeklyContributionEmployee> onOpenEmployee;

  const ManagerWeeklyContributionSection({
    super.key,
    required this.future,
    required this.onOpenEmployee,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ManagerWeeklyContributionReport>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ManagerReportTile(
            icon: Icons.groups_2_outlined,
            title: 'Вклад команды за неделю',
            meta: 'Загрузка недельной сводки',
            loading: true,
          );
        }
        if (snapshot.hasError) {
          return const ManagerReportTile(
            icon: Icons.groups_2_outlined,
            title: 'Вклад команды за неделю',
            meta: 'Не удалось загрузить сводку',
          );
        }
        return _WeeklyContributionCard(
          report:
              snapshot.data ??
              ManagerWeeklyContributionReport(
                weekStart: DateTime.now(),
                weekEnd: DateTime.now(),
                completedTasks: 0,
                participants: 0,
                objectsCount: 0,
                rows: const <ManagerWeeklyContributionEmployee>[],
              ),
          onOpenEmployee: onOpenEmployee,
        );
      },
    );
  }
}

class _WeeklyContributionCard extends StatelessWidget {
  final ManagerWeeklyContributionReport report;
  final ValueChanged<ManagerWeeklyContributionEmployee> onOpenEmployee;

  const _WeeklyContributionCard({
    required this.report,
    required this.onOpenEmployee,
  });

  String get periodTitle {
    final format = DateFormat('dd.MM.yyyy');
    return '${format.format(report.weekStart)} — ${format.format(report.weekEnd)}';
  }

  @override
  Widget build(BuildContext context) {
    return ManagerReportTile(
      icon: Icons.groups_2_outlined,
      title: 'Вклад команды за неделю',
      meta: '$periodTitle · ${report.participants} участников',
      trailingLabel: report.completedTasks > 0
          ? '${report.completedTasks}'
          : null,
      onTap: () {
        Navigator.of(context).push<void>(
          AppPageRoute<void>(
            builder: (_) => _WeeklyContributionDetailsScreen(
              report: report,
              onOpenEmployee: onOpenEmployee,
            ),
          ),
        );
      },
    );
  }
}

class _WeeklyContributionDetailsScreen extends StatelessWidget {
  final ManagerWeeklyContributionReport report;
  final ValueChanged<ManagerWeeklyContributionEmployee> onOpenEmployee;

  const _WeeklyContributionDetailsScreen({
    required this.report,
    required this.onOpenEmployee,
  });

  String get periodTitle {
    final format = DateFormat('dd.MM.yyyy');
    return '${format.format(report.weekStart)} — ${format.format(report.weekEnd)}';
  }

  String number(double value) => NumberFormat('0.##', 'ru_RU').format(value);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppPage(
      title: 'Вклад команды',
      subtitle: '$periodTitle · завершённая неделя',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumWorkCard(
            radius: 24,
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Metric(label: 'Задач', value: '${report.completedTasks}'),
                _Metric(label: 'Участников', value: '${report.participants}'),
                _Metric(label: 'Объектов', value: '${report.objectsCount}'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Участники',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (report.rows.isEmpty)
            PremiumWorkCard(
              radius: 24,
              padding: const EdgeInsets.all(16),
              child: Text(
                'За эту завершённую неделю вклад пока не зафиксирован.',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            PremiumWorkCard(
              radius: 24,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var index = 0; index < report.rows.length; index++) ...[
                    _EmployeeContributionTile(
                      item: report.rows[index],
                      equivalentTitle: number(
                        report.rows[index].equivalentTasks,
                      ),
                      onTap: () => onOpenEmployee(report.rows[index]),
                    ),
                    if (index < report.rows.length - 1)
                      Divider(height: 1, color: scheme.outlineVariant),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

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

class _EmployeeContributionTile extends StatelessWidget {
  final ManagerWeeklyContributionEmployee item;
  final String equivalentTitle;
  final VoidCallback onTap;

  const _EmployeeContributionTile({
    required this.item,
    required this.equivalentTitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = <String>[
      if (item.position.trim().isNotEmpty) item.position.trim(),
      if (item.objectName.trim().isNotEmpty) item.objectName.trim(),
      '${item.taskCount} задач',
    ].join(' · ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
      title: Text(
        item.employeeName,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(secondary),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$equivalentTitle задачи',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          Text(
            '${NumberFormat('0.#', 'ru_RU').format(item.teamSharePercent)}% команды',
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
