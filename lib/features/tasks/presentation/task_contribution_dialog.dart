import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skbs_app/widgets/app_input_formatters.dart';

import '../../../data/task_contribution_repository.dart';
import '../../work_orders/work_order_fields.dart';

class TaskCompletionWorkResult {
  const TaskCompletionWorkResult({
    required this.actualQuantity,
    required this.unit,
    required this.entries,
  });

  final double? actualQuantity;
  final String unit;
  final List<TaskContributionEntry> entries;

  List<Map<String, dynamic>> get workOrderParticipants => [
    for (final entry in entries)
      <String, dynamic>{
        'employee_id': entry.employeeId,
        'ktu': entry.percent,
      },
  ];

  /// The old contribution report expects a 100% distribution. Keep that
  /// report compatible while KTU itself remains independent in the UI.
  List<TaskContributionEntry> get normalizedContributions {
    final total = entries.fold<int>(0, (sum, item) => sum + item.percent);
    final raw = [for (final entry in entries) 100 * entry.percent / total];
    final normalized = raw.map((value) => value.floor()).toList();
    var remainder =
        100 - normalized.fold<int>(0, (sum, value) => sum + value);
    final order = List<int>.generate(entries.length, (index) => index)
      ..sort((first, second) {
        final firstPart = raw[first] - normalized[first];
        final secondPart = raw[second] - normalized[second];
        final comparison = secondPart.compareTo(firstPart);
        return comparison == 0 ? first.compareTo(second) : comparison;
      });
    for (final index in order) {
      if (remainder-- <= 0) break;
      normalized[index]++;
    }
    return [
      for (var index = 0; index < entries.length; index++)
        entries[index].copyWith(percent: normalized[index]),
    ];
  }
}

Future<TaskCompletionWorkResult?> showTaskContributionDialog({
  required BuildContext context,
  required List<TaskContributionEntry> entries,
  required String unit,
  double? plannedQuantity,
  double? initialActualQuantity,
  bool withoutVolume = false,
  Map<String, int> initialKtu = const <String, int>{},
}) {
  return showDialog<TaskCompletionWorkResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TaskContributionDialog(
      entries: entries,
      unit: unit,
      plannedQuantity: plannedQuantity,
      initialActualQuantity: initialActualQuantity,
      withoutVolume: withoutVolume,
      initialKtu: initialKtu,
    ),
  );
}

class _TaskContributionDialog extends StatefulWidget {
  const _TaskContributionDialog({
    required this.entries,
    required this.unit,
    required this.plannedQuantity,
    required this.initialActualQuantity,
    required this.initialKtu,
    required this.withoutVolume,
  });

  final List<TaskContributionEntry> entries;
  final String unit;
  final double? plannedQuantity;
  final double? initialActualQuantity;
  final Map<String, int> initialKtu;
  final bool withoutVolume;

  @override
  State<_TaskContributionDialog> createState() =>
      _TaskContributionDialogState();
}

class _TaskContributionDialogState extends State<_TaskContributionDialog> {
  late List<TaskContributionEntry> entries;
  late final TextEditingController actualController;

  @override
  void initState() {
    super.initState();
    entries = [
      for (final entry in widget.entries)
        entry.copyWith(
          percent: (widget.initialKtu[entry.employeeId] ?? 100)
              .clamp(0, 200)
              .toInt(),
        ),
    ];
    actualController = TextEditingController(
      text: AppInputFormatters.formatNumber(
        widget.initialActualQuantity?.toString() ?? '',
      ),
    );
  }

  @override
  void dispose() {
    actualController.dispose();
    super.dispose();
  }

  void changeKtu(int index, int value) {
    setState(() {
      entries[index] = entries[index].copyWith(
        percent: value.clamp(0, 200).toInt(),
      );
    });
  }

  void confirm() {
    final actual = widget.withoutVolume
        ? null
        : parseWorkQuantity(actualController.text);
    if (!widget.withoutVolume && !isValidWorkQuantity(actual)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите выполненный объём больше нуля')),
      );
      return;
    }
    if (entries.isEmpty || entries.every((entry) => entry.percent == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Хотя бы у одного работника КТУ должен быть больше нуля',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      TaskCompletionWorkResult(
        actualQuantity: actual,
        unit: widget.withoutVolume ? '' : widget.unit,
        entries: List<TaskContributionEntry>.from(entries),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxHeight = math.min(MediaQuery.sizeOf(context).height * 0.78, 680.0);
    return AlertDialog(
      title: const Text('Завершение задачи'),
      content: SizedBox(
        width: 560,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.withoutVolume && widget.plannedQuantity != null) ...[
                Text(
                  'План: ${widget.plannedQuantity} ${widget.unit}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (!widget.withoutVolume) ...[
                TextField(
                  controller: actualController,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: AppInputFormatters.groupedNumber,
                  decoration: InputDecoration(
                    labelText: 'Фактически выполненный объём',
                    suffixText: widget.unit,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                'КТУ каждого работника задаётся отдельно: 0–200%, обычное участие — 100%.',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 6),
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
                              SizedBox(
                                width: 72,
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
                            max: 200,
                            divisions: 200,
                            value: entry.percent.toDouble(),
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
          label: const Text('Завершить задачу'),
        ),
      ],
    );
  }
}
