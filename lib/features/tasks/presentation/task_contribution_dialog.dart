import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/task_contribution_repository.dart';
import '../../work_orders/work_order_repository.dart';

class TaskCompletionWorkResult {
  final double quantity;
  final String unit;
  final List<TaskContributionEntry> entries;

  const TaskCompletionWorkResult({
    required this.quantity,
    required this.unit,
    required this.entries,
  });
}

Future<TaskCompletionWorkResult?> showTaskContributionDialog({
  required BuildContext context,
  required List<TaskContributionEntry> entries,
  double? initialQuantity,
  String initialUnit = '',
  double? plannedQuantity,
}) {
  return showDialog<TaskCompletionWorkResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TaskContributionDialog(
      entries: entries,
      initialQuantity: initialQuantity,
      initialUnit: initialUnit,
      plannedQuantity: plannedQuantity,
    ),
  );
}

class _TaskContributionDialog extends StatefulWidget {
  final List<TaskContributionEntry> entries;
  final double? initialQuantity;
  final String initialUnit;
  final double? plannedQuantity;

  const _TaskContributionDialog({
    required this.entries,
    required this.initialQuantity,
    required this.initialUnit,
    required this.plannedQuantity,
  });

  @override
  State<_TaskContributionDialog> createState() =>
      _TaskContributionDialogState();
}

class _TaskContributionDialogState extends State<_TaskContributionDialog> {
  late List<TaskContributionEntry> entries;
  late String selectedUnit;
  late final bool unitLocked;
  final TextEditingController quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    entries = <TaskContributionEntry>[
      for (final entry in widget.entries)
        entry.copyWith(percent: entry.percent.clamp(0, 200).toInt()),
    ];
    final incomingUnit = widget.initialUnit.trim();
    unitLocked = incomingUnit.isNotEmpty;
    selectedUnit = incomingUnit.isEmpty
        ? WorkOrderRepository.supportedUnits.first
        : incomingUnit;
    final initialQuantity = widget.initialQuantity;
    if (initialQuantity != null) {
      quantityController.text = _number(initialQuantity);
    }
  }

  @override
  void dispose() {
    quantityController.dispose();
    super.dispose();
  }

  String _number(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  double? _quantity() => double.tryParse(
    quantityController.text.trim().replaceAll(',', '.'),
  );

  void changeKtu(int index, int requestedValue) {
    final value = requestedValue.clamp(0, 200).toInt();
    setState(() {
      final updated = List<TaskContributionEntry>.from(entries);
      updated[index] = updated[index].copyWith(percent: value);
      entries = updated;
    });
  }

  void confirm() {
    final quantity = _quantity();
    if (quantity == null || !quantity.isFinite || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите фактически выполненный объём больше 0')),
      );
      return;
    }
    if (entries.isEmpty || !entries.any((entry) => entry.percent > 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Хотя бы у одного сотрудника КТУ должен быть больше 0')),
      );
      return;
    }
    Navigator.of(context).pop(
      TaskCompletionWorkResult(
        quantity: quantity,
        unit: selectedUnit,
        entries: List<TaskContributionEntry>.from(entries),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxHeight = math.min(MediaQuery.sizeOf(context).height * 0.78, 680.0);
    final unitOptions = WorkOrderRepository.unitOptions(selectedUnit);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      title: const Text('Объём и КТУ'),
      content: SizedBox(
        width: 560,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Укажите фактически выполненный объём и КТУ каждого участника. Значения КТУ независимы: изменение одного сотрудника не меняет остальных.',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              if (widget.plannedQuantity != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Плановый объём: ${_number(widget.plannedQuantity!)} $selectedUnit',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final quantityField = TextField(
                    controller: quantityController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Фактически выполненный объём',
                      hintText: '0',
                      border: OutlineInputBorder(),
                    ),
                  );
                  final unitField = DropdownButtonFormField<String>(
                    key: ValueKey('completion-work-unit-$selectedUnit'),
                    initialValue: selectedUnit,
                    decoration: const InputDecoration(
                      labelText: 'Ед.',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final unit in unitOptions)
                        DropdownMenuItem<String>(
                          value: unit,
                          child: Text(unit),
                        ),
                    ],
                    onChanged: unitLocked
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => selectedUnit = value);
                          },
                  );
                  if (constraints.maxWidth < 360) {
                    return Column(
                      children: [
                        quantityField,
                        const SizedBox(height: 10),
                        unitField,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: quantityField),
                      const SizedBox(width: 10),
                      SizedBox(width: 112, child: unitField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              Text(
                'КТУ сотрудников',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '0 — не участвовал · 100 — обычное участие · 200 — максимальный вклад',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('0', style: TextStyle(fontSize: 11)),
                              Text(
                                '100',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text('200', style: TextStyle(fontSize: 11)),
                            ],
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
