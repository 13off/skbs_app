import 'dart:math' as math;

import 'package:flutter/material.dart';

class TaskKtuEntry {
  final String employeeId;
  final String employeeName;
  final String position;
  final int ktu;

  const TaskKtuEntry({
    required this.employeeId,
    required this.employeeName,
    required this.position,
    this.ktu = 100,
  });

  TaskKtuEntry copyWith({int? ktu}) {
    return TaskKtuEntry(
      employeeId: employeeId,
      employeeName: employeeName,
      position: position,
      ktu: ktu ?? this.ktu,
    );
  }
}

class TaskCompletionWorkResult {
  final double actualVolume;
  final List<TaskKtuEntry> participants;

  const TaskCompletionWorkResult({
    required this.actualVolume,
    required this.participants,
  });
}

Future<TaskCompletionWorkResult?> showTaskContributionDialog({
  required BuildContext context,
  required List<TaskKtuEntry> entries,
  required String unitLabel,
  double? plannedQuantity,
}) {
  return showDialog<TaskCompletionWorkResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TaskContributionDialog(
      entries: entries,
      unitLabel: unitLabel,
      plannedQuantity: plannedQuantity,
    ),
  );
}

class _TaskContributionDialog extends StatefulWidget {
  final List<TaskKtuEntry> entries;
  final String unitLabel;
  final double? plannedQuantity;

  const _TaskContributionDialog({
    required this.entries,
    required this.unitLabel,
    required this.plannedQuantity,
  });

  @override
  State<_TaskContributionDialog> createState() =>
      _TaskContributionDialogState();
}

class _TaskContributionDialogState extends State<_TaskContributionDialog> {
  final TextEditingController actualController = TextEditingController();
  late List<TaskKtuEntry> entries;

  @override
  void initState() {
    super.initState();
    entries = <TaskKtuEntry>[
      for (final entry in widget.entries) entry.copyWith(ktu: 100),
    ];
  }

  @override
  void dispose() {
    actualController.dispose();
    super.dispose();
  }

  void changeKtu(int index, int value) {
    final normalized = value.clamp(0, 200).toInt();
    setState(() {
      final updated = List<TaskKtuEntry>.from(entries);
      updated[index] = updated[index].copyWith(ktu: normalized);
      entries = updated;
    });
  }

  void confirm() {
    final actual = double.tryParse(
      actualController.text.trim().replaceAll(',', '.'),
    );
    if (actual == null || !actual.isFinite || actual <= 0 || actual > 1e12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите фактически выполненный объём')),
      );
      return;
    }
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы одного исполнителя')),
      );
      return;
    }
    if (!entries.any((entry) => entry.ktu > 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Хотя бы у одного исполнителя КТУ должен быть больше 0')),
      );
      return;
    }

    Navigator.of(context).pop(
      TaskCompletionWorkResult(
        actualVolume: actual,
        participants: List<TaskKtuEntry>.from(entries),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final maxHeight = math.min(size.height * 0.76, 650.0);
    final contentWidth = math.max(240.0, math.min(560.0, size.width - 64));
    final planned = widget.plannedQuantity;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Задача выполнена'),
      content: SizedBox(
        width: contentWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: actualController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Фактически выполненный объём',
                  suffixText: widget.unitLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (planned != null) ...[
                const SizedBox(height: 8),
                Text(
                  'План: ${planned.toStringAsFixed(planned.truncateToDouble() == planned ? 0 : 3)} ${widget.unitLabel}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                'КТУ исполнителей',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '100 — обычный уровень. КТУ каждого сотрудника задаётся независимо от остальных: от 0 до 200.',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  separatorBuilder: (_, _) =>
                      Divider(color: scheme.outlineVariant),
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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
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
                              const SizedBox(width: 8),
                              Text(
                                'КТУ ${entry.ktu}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            min: 0,
                            max: 200,
                            divisions: 200,
                            value: entry.ktu.toDouble(),
                            onChanged: (value) =>
                                changeKtu(index, value.round()),
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
          label: const Text('Подтвердить выполнение'),
        ),
      ],
    );
  }
}
