import 'dart:convert';

import 'package:flutter/material.dart';

import 'work_order_fields.dart';
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
  final planned = TextEditingController();
  String unit = workOrderUnits.first;
  bool withoutVolume = false;
  String baseline = '';
  bool loading = true;
  bool busy = false;
  String? error;

  String get signature => jsonEncode([planned.text, unit, withoutVolume]);
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

  Future<void> load() async {
    try {
      final plan = await WorkOrderRepository.plan(widget.taskId);
      if (!mounted) return;
      planned.text = plan?['planned_quantity']?.toString() ?? '';
      final savedUnit = plan?['unit']?.toString() ?? '';
      withoutVolume = plan?['without_volume'] == true;
      unit = workOrderUnits.contains(savedUnit)
          ? savedUnit
          : workOrderUnits.first;
      baseline = signature;
      setState(() {
        loading = false;
        error = null;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Не удалось загрузить плановый объём: $exception';
      });
    }
  }

  Future<bool> saveIfDirty() async {
    if (!dirty) return true;
    return save();
  }

  Future<bool> save() async {
    if (busy || loading) return false;
    final value = parseWorkQuantity(planned.text);
    if (!withoutVolume &&
        planned.text.trim().isNotEmpty &&
        !isValidWorkQuantity(value)) {
      setState(() => error = 'Введите плановый объём больше нуля');
      return false;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await WorkOrderRepository.savePlan(
        taskId: widget.taskId,
        planned: withoutVolume ? null : value,
        unit: withoutVolume ? '' : unit,
        withoutVolume: withoutVolume,
      );
      baseline = signature;
      return true;
    } catch (exception) {
      if (mounted) {
        setState(() => error = 'Не удалось сохранить объём: $exception');
      }
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 12),
            if (loading)
              const LinearProgressIndicator()
            else
              WorkOrderPlanFields(
                quantityController: planned,
                unit: unit,
                enabled: widget.canEdit && !busy,
                withoutVolume: withoutVolume,
                onWithoutVolumeChanged: (value) {
                  setState(() => withoutVolume = value ?? false);
                },
                onUnitChanged: (value) {
                  if (value != null) setState(() => unit = value);
                },
              ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
