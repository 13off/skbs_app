import 'dart:convert';

import 'package:flutter/material.dart';

import 'work_order_repository.dart';

class TaskWorkSection extends StatefulWidget {
  const TaskWorkSection({
    super.key,
    required this.taskId,
    required this.initialDate,
    required this.canEdit,
  });

  final String taskId;
  final DateTime initialDate;
  final bool canEdit;

  @override
  State<TaskWorkSection> createState() => TaskWorkSectionState();
}

class TaskWorkSectionState extends State<TaskWorkSection> {
  final TextEditingController planned = TextEditingController();
  String selectedUnit = WorkOrderRepository.unitOptions.first;
  String baseline = '';
  bool loading = true;
  bool busy = false;
  String? error;

  String get signature => jsonEncode(<String>[planned.text, selectedUnit]);
  bool get dirty => !loading && baseline.isNotEmpty && signature != baseline;

  Future<bool> saveIfDirty() async => !dirty || await save(notify: false);

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    planned.dispose();
    super.dispose();
  }

  double? number(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  Future<void> load() async {
    try {
      final plan = await WorkOrderRepository.plan(widget.taskId);
      if (!mounted) return;
      planned.text = plan?['planned_quantity']?.toString() ?? '';
      final savedUnit = plan?['unit']?.toString().trim() ?? '';
      if (savedUnit.isNotEmpty) selectedUnit = savedUnit;
      baseline = signature;
      setState(() {
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Не удалось загрузить плановый объём: $e';
      });
    }
  }

  Future<bool> save({bool notify = true}) async {
    if (busy || loading || !widget.canEdit) return false;
    final value = number(planned.text);
    if (planned.text.trim().isEmpty ||
        value == null ||
        !value.isFinite ||
        value <= 0 ||
        value > 1e12) {
      setState(() => error = 'Проверьте плановый объём');
      return false;
    }
    if (selectedUnit.trim().isEmpty) {
      setState(() => error = 'Выберите единицу измерения');
      return false;
    }

    setState(() {
      busy = true;
      error = null;
    });
    try {
      await WorkOrderRepository.save(
        taskId: widget.taskId,
        planned: value,
        unit: selectedUnit,
        date: widget.initialDate,
        quantity: null,
        participants: const <Map<String, dynamic>>[],
      );
      baseline = signature;
      if (mounted) {
        setState(() {});
        if (notify) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Плановый объём сохранён')),
          );
        }
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              'Не удалось сохранить план. Проверьте интернет и синхронизацию задачи. $e',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final units = <String>[
      ...WorkOrderRepository.unitOptions,
      if (!WorkOrderRepository.unitOptions.contains(selectedUnit)) selectedUnit,
    ].where((item) => item.trim().isNotEmpty).toSet().toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Объём и наряд',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Плановый объём задачи',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (loading)
              const LinearProgressIndicator()
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: planned,
                      enabled: widget.canEdit && !busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Количество',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 108,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Ед.',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: units.contains(selectedUnit)
                              ? selectedUnit
                              : units.first,
                          isExpanded: true,
                          isDense: true,
                          items: units
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: !widget.canEdit || busy
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() => selectedUnit = value);
                                },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.canEdit) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: busy ? null : () => save(),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(busy ? 'Сохранение…' : 'Сохранить план'),
                ),
              ],
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: busy ? null : load,
                child: const Text('Повторить загрузку'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
