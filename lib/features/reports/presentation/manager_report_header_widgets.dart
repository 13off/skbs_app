import 'package:flutter/material.dart';

import '../../../widgets/premium_ui.dart';
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
    final objectField = DropdownButtonFormField<String>(
      key: ValueKey<String?>(selectedObjectId),
      initialValue: selectedObjectId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Объект',
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
            child: Text(object.name, overflow: TextOverflow.ellipsis),
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

    final problemsSwitch = Row(
      children: [
        const Expanded(
          child: Text(
            'Только проблемные разделы',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        Switch.adaptive(
          value: onlyProblems,
          onChanged: onOnlyProblemsChanged,
        ),
      ],
    );

    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 760) {
            return Row(
              children: [
                Expanded(flex: 4, child: objectField),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: dateField),
                const SizedBox(width: 16),
                SizedBox(width: 230, child: problemsSwitch),
              ],
            );
          }
          return Column(
            children: [
              objectField,
              const SizedBox(height: 10),
              dateField,
              const SizedBox(height: 4),
              problemsSwitch,
            ],
          );
        },
      ),
    );
  }
}

class ManagerReportOverview extends StatelessWidget {
  final ManagerReportsCenter center;

  const ManagerReportOverview({super.key, required this.center});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final critical = center.criticalCount;
    final lines = ManagerReportAnalysis.lines(center).take(2).toList();

    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              critical > 0
                  ? Icons.warning_amber_rounded
                  : Icons.verified_outlined,
              color: critical > 0 ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        critical > 0
                            ? 'Требует внимания'
                            : 'Отклонений не найдено',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (critical > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$critical',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                  ],
                ),
                if (lines.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  for (var index = 0; index < lines.length; index++) ...[
                    Text(
                      lines[index],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (index != lines.length - 1) const SizedBox(height: 3),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
