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
  String unit = WorkOrderRepository.supportedUnits.first;
  String baseline = '';
  bool loading = true;
  bool busy = false;
  String? error;

  String get signature => '${planned.text.trim()}|$unit';
  bool get dirty => !loading && baseline.isNotEmpty && signature != baseline;

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

  Future<bool> saveIfDirty() async => !dirty || await save(notify: false);

  Future<void> load() async {
    try {
      final plan = await WorkOrderRepository.plan(widget.taskId);
      if (!mounted) return;
      planned.text = plan?['planned_quantity']?.toString() ?? '';
      final savedUnit = plan?['unit']?.toString().trim() ?? '';
      unit = savedUnit.isEmpty ? WorkOrderRepository.supportedUnits.first : savedUnit;
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
    if (busy || loading) return false;
    final value = number(planned.text);
    if (value == null || !value.isFinite || value <= 0) {
      setState(() => error = 'Плановый объём должен быть больше 0');
      return false;
    }
    if (unit.trim().isEmpty) {
      setState(() => error = 'Выберите единицу измерения');
      return false;
    }

    setState(() {
      busy = true;
      error = null;
    });
    try {
      await WorkOrderRepository.savePlan(
        taskId: widget.taskId,
        planned: value,
        unit: unit,
        date: widget.initialDate,
      );
      baseline = signature;
      if (mounted && notify) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Плановый объём сохранён')),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => error = 'Не удалось сохранить плановый объём: $e');
      }
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unitOptions = WorkOrderRepository.unitOptions(unit);
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
              'Здесь хранится план задачи. Фактический объём и КТУ мастер указывает при завершении задачи.',
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
                        labelText: 'Плановый объём',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 118,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('task-work-unit-$unit'),
                      initialValue: unit,
                      decoration: const InputDecoration(
                        labelText: 'Ед.',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final value in unitOptions)
                          DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                      ],
                      onChanged: !widget.canEdit || busy
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() => unit = value);
                            },
                    ),
                  ),
                ],
              ),
              if (widget.canEdit) ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: busy ? null : () => save(),
                  child: Text(busy ? 'Сохранение…' : 'Сохранить объём'),
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
