import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/task_contribution_repository.dart';

Future<List<TaskContributionEntry>?> showTaskContributionDialog({
  required BuildContext context,
  required List<TaskContributionEntry> entries,
}) {
  return showDialog<List<TaskContributionEntry>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TaskContributionDialog(entries: entries),
  );
}

class _TaskContributionDialog extends StatefulWidget {
  final List<TaskContributionEntry> entries;

  const _TaskContributionDialog({required this.entries});

  @override
  State<_TaskContributionDialog> createState() => _TaskContributionDialogState();
}

class _TaskContributionDialogState extends State<_TaskContributionDialog> {
  late List<TaskContributionEntry> entries;

  @override
  void initState() {
    super.initState();
    entries = List<TaskContributionEntry>.from(widget.entries);
  }

  int get total => entries.fold<int>(0, (sum, item) => sum + item.percent);

  void distributeEqually() {
    final percents = TaskContributionRepository.equalPercents(entries.length);
    setState(() {
      entries = <TaskContributionEntry>[
        for (var index = 0; index < entries.length; index++)
          entries[index].copyWith(percent: percents[index]),
      ];
    });
  }

  void changePercent(int changedIndex, int requestedPercent) {
    if (entries.length <= 1) return;
    final target = requestedPercent.clamp(0, 100).toInt();
    final remaining = 100 - target;
    final otherIndexes = <int>[
      for (var index = 0; index < entries.length; index++)
        if (index != changedIndex) index,
    ];
    final currentOtherTotal = otherIndexes.fold<int>(
      0,
      (sum, index) => sum + entries[index].percent,
    );
    final weights = <double>[
      for (final index in otherIndexes)
        currentOtherTotal == 0
            ? 1
            : entries[index].percent / currentOtherTotal,
    ];
    final raw = <double>[
      for (final weight in weights)
        currentOtherTotal == 0
            ? remaining / otherIndexes.length
            : remaining * weight,
    ];
    final next = raw.map((value) => value.floor()).toList();
    var missing = remaining - next.fold<int>(0, (sum, value) => sum + value);
    final fractionalOrder = List<int>.generate(raw.length, (index) => index)
      ..sort((first, second) {
        final firstPart = raw[first] - raw[first].floor();
        final secondPart = raw[second] - raw[second].floor();
        return secondPart.compareTo(firstPart);
      });
    for (final index in fractionalOrder) {
      if (missing <= 0) break;
      next[index]++;
      missing--;
    }

    setState(() {
      final updated = List<TaskContributionEntry>.from(entries);
      updated[changedIndex] = updated[changedIndex].copyWith(percent: target);
      for (var offset = 0; offset < otherIndexes.length; offset++) {
        final index = otherIndexes[offset];
        updated[index] = updated[index].copyWith(percent: next[offset]);
      }
      entries = updated;
    });
  }

  void confirm() {
    if (entries.isEmpty || total != 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Общий вклад должен составлять 100%')),
      );
      return;
    }
    Navigator.of(context).pop(List<TaskContributionEntry>.from(entries));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxHeight = math.min(MediaQuery.sizeOf(context).height * 0.72, 620.0);
    return AlertDialog(
      title: const Text('Вклад в результат'),
      content: SizedBox(
        width: 560,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Распределите 100% между участниками задачи. По умолчанию вклад разделён поровну.',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: total == 100
                          ? scheme.primaryContainer
                          : scheme.errorContainer,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'Всего: $total%',
                      style: TextStyle(
                        color: total == 100
                            ? scheme.onPrimaryContainer
                            : scheme.onErrorContainer,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: distributeEqually,
                    icon: const Icon(Icons.balance_rounded, size: 18),
                    label: const Text('Поровну'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => Divider(color: scheme.outlineVariant),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.employeeName,
                                      style: const TextStyle(fontWeight: FontWeight.w900),
                                    ),
                                    if (entry.position.trim().isNotEmpty)
                                      Text(
                                        entry.position,
                                        style: TextStyle(
                                          color: scheme.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 62,
                                child: Text(
                                  '${entry.percent}%',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            min: 0,
                            max: 100,
                            divisions: 100,
                            value: entry.percent.toDouble(),
                            onChanged: entries.length == 1
                                ? null
                                : (value) => changePercent(index, value.round()),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Вернуться к задаче'),
        ),
        FilledButton.icon(
          onPressed: confirm,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Подтвердить вклад'),
        ),
      ],
    );
  }
}
