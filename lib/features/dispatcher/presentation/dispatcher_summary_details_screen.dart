import 'package:flutter/material.dart';

import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/dispatcher_summary_details_repository.dart';

class DispatcherSummaryDetailsScreen extends StatefulWidget {
  final String runId;

  const DispatcherSummaryDetailsScreen({
    super.key,
    required this.runId,
  });

  @override
  State<DispatcherSummaryDetailsScreen> createState() =>
      _DispatcherSummaryDetailsScreenState();
}

class _DispatcherSummaryDetailsScreenState
    extends State<DispatcherSummaryDetailsScreen> {
  late Future<DispatcherSummaryDetails> detailsFuture;
  final Set<String> expandedGroups = <String>{};

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    detailsFuture = DispatcherSummaryDetailsRepository.fetch(widget.runId);
  }

  String dateText(DateTime? value) {
    if (value == null) return 'Без даты';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  IconData iconFor(String key) {
    return switch (key) {
      'payments_missing_receipts' => Icons.receipt_long_outlined,
      'tasks_blocked' => Icons.report_problem_outlined,
      'tasks_pending' => Icons.task_alt_outlined,
      'attendance_missing' => Icons.fact_check_outlined,
      'legal_overdue' => Icons.event_busy_outlined,
      'legal_high_risk' => Icons.gavel_outlined,
      'documents_expiring' => Icons.description_outlined,
      'milestones_overdue' => Icons.flag_outlined,
      _ => Icons.warning_amber_rounded,
    };
  }

  Widget headerCard(DispatcherSummaryDetails details) {
    final changed = details.changedSinceSummary;
    return PremiumWorkCard(
      radius: 28,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.analytics_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      details.objectName,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Сводка за ${dateText(details.summaryDate)}',
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
          Text(
            'В сводку вошло отклонений: ${details.originalCriticalCount}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          if (changed) ...[
            const SizedBox(height: 8),
            Text(
              'Сейчас открыто ${details.currentCriticalCount}. Часть данных изменилась после формирования сводки.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget groupCard(DispatcherDetailGroup group) {
    final expanded = expandedGroups.contains(group.key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
                  child: Icon(iconFor(group.key)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        group.includedInTotal
                            ? 'Входит в итоговое число отклонений'
                            : 'Показано для контроля, в итог не входит',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${group.count}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  expanded
                      ? expandedGroups.remove(group.key)
                      : expandedGroups.add(group.key);
                });
              },
              icon: Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
              ),
              label: Text(
                expanded ? 'Скрыть список' : 'Показать ${group.count}',
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 8),
              for (var index = 0; index < group.items.length; index++) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(
                    group.items[index].title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (group.items[index].subtitle.isNotEmpty)
                        Text(group.items[index].subtitle),
                      if (group.items[index].note.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          group.items[index].note,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (index != group.items.length - 1)
                  const Divider(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Разбор сводки',
      showBackButton: true,
      subtitle: 'Из чего сложились отклонения ИИ-диспетчера',
      headerTrailing: IconButton(
        tooltip: 'Обновить',
        onPressed: () => setState(reload),
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: FutureBuilder<DispatcherSummaryDetails>(
        future: detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return PremiumWorkCard(
              radius: 22,
              padding: const EdgeInsets.all(16),
              child: Text(
                'Не удалось загрузить разбор: ${snapshot.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            );
          }

          final details = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              headerCard(details),
              sectionTitle(
                'Отклонения',
                'Эти пункты складываются в итоговое число в сводке.',
              ),
              if (details.deviations.isEmpty)
                const PremiumWorkCard(
                  radius: 22,
                  child: Text('Открытых отклонений сейчас нет.'),
                )
              else
                ...details.deviations.map(groupCard),
              if (details.contextGroups.isNotEmpty) ...[
                sectionTitle(
                  'Дополнительно',
                  'Важные незакрытые пункты, которые не входят в число отклонений.',
                ),
                ...details.contextGroups.map(groupCard),
              ],
            ],
          );
        },
      ),
    );
  }
}
