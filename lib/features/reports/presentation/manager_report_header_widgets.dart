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
