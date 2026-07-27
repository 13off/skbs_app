import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../widgets/premium_ui.dart';
import '../data/manager_weekly_contribution_repository.dart';

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
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: PremiumWorkCard(
              radius: 24,
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PremiumWorkCard(
              radius: 24,
              child: ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: const Text(
                  'Вклад команды за неделю',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: const Text('Не удалось загрузить недельную сводку'),
              ),
            ),
          );
        }
        return _WeeklyContributionCard(
          report: snapshot.data ??
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

  String number(double value) => NumberFormat('0.##', 'ru_RU').format(value);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumWorkCard(
        radius: 24,
        padding: EdgeInsets.zero,
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.groups_2_outlined),
          ),
          title: const Text(
            'Вклад команды за неделю',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            '$periodTitle · обновляется после завершения недели',
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
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
            const SizedBox(height: 12),
            if (report.rows.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'За эту завершённую неделю вклад пока не зафиксирован.',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(18),
                ),
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
