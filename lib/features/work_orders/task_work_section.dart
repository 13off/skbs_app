import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/task_assignee_repository.dart';
import 'work_order_repository.dart';

class TaskWorkSection extends StatefulWidget {
  const TaskWorkSection({super.key, required this.taskId,
    required this.initialDate, required this.canEdit});
  final String taskId;
  final DateTime initialDate;
  final bool canEdit;
  @override
  State<TaskWorkSection> createState() => TaskWorkSectionState();
}

class TaskWorkSectionState extends State<TaskWorkSection> {
  final planned = TextEditingController();
  final unit = TextEditingController();
  final actual = TextEditingController();
  final Map<String, TextEditingController> ktu = {};
  final Map<String, String> names = {};
  final Set<String> selected = {};
  final Set<String> currentAssignees = {};
  String baseline = '';
  String get signature => jsonEncode([planned.text, unit.text, actual.text,
      selected.toList()..sort(), {for (final id in selected) id: ktu[id]?.text}]);
  bool get dirty => !loading && baseline.isNotEmpty && signature != baseline;
  Future<bool> saveIfDirty() async => !dirty || await save(notify: false);
  List<Map<String, dynamic>> days = [];
  late DateTime date;
  bool loading = true;
  bool busy = false;
  String? error;

  @override
  void initState() { super.initState(); date = DateUtils.dateOnly(widget.initialDate); load(); }
  @override
  void dispose() {
    planned.dispose(); unit.dispose(); actual.dispose();
    for (final controller in ktu.values) { controller.dispose(); }
    super.dispose();
  }
  double? number(String value) => double.tryParse(value.trim().replaceAll(',', '.'));
  bool valid(double? value) => value != null && value.isFinite && value >= 0 && value <= 1e12;
  Future<void> load() async {
    try {
      final plan = await WorkOrderRepository.plan(widget.taskId);
      final records = await WorkOrderRepository.days(widget.taskId);
      final assignees = await TaskAssigneeRepository.fetchAssignees(widget.taskId);
      if (!mounted) return;
      planned.text = plan?['planned_quantity']?.toString() ?? '';
      unit.text = plan?['unit']?.toString() ?? '';
      days = records;
      currentAssignees.clear();
      for (final person in assignees) {
        currentAssignees.add(person.employeeId);
        names[person.employeeId] = person.employeeName;
        ktu.putIfAbsent(person.employeeId, () => TextEditingController(text: '100'));
      }
      selectDay(date);
      baseline = signature;
      setState(() { loading = false; error = null; });
    } catch (e) {
      if (mounted) setState(() { loading = false; error = 'Не удалось загрузить объёмы: $e'; });
    }
  }
  void selectDay(DateTime value) {
    date = value;
    final found = days.where((d) => d['work_date'] == WorkOrderRepository.dateKey(date));
    selected.clear();
    for (final controller in ktu.values) { controller.text = '100'; }
    if (found.isEmpty) {
      actual.clear(); selected.addAll(currentAssignees);
    } else {
      final record = found.first;
      actual.text = '${record['quantity']}';
      unit.text = '${record['unit']}';
      for (final raw in record['participants'] as List) {
        final person = Map<String, dynamic>.from(raw as Map);
        final id = '${person['employee_id']}';
        names[id] = '${person['fio']}';
        ktu.putIfAbsent(id, () => TextEditingController());
        ktu[id]!.text = '${person['ktu']}'; selected.add(id);
      }
    }
  }
  Future<void> changeDay(DateTime value) async {
    if (dirty) {
      final discard = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('Есть несохранённый объём'),
        content: const Text('Перейти к другому дню и отменить введённые изменения?'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Остаться')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Перейти'))],
      ));
      if (discard != true || !mounted) return;
      final saved = jsonDecode(baseline) as List;
      planned.text = saved[0] as String;
      unit.text = saved[1] as String;
    }
    setState(() => selectDay(value));
    baseline = signature;
  }
  Future<void> pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: date,
        firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null && mounted) await changeDay(picked);
  }
  Future<bool> save({bool notify = true}) async {
    if (busy || loading) return false;
    final plan = planned.text.trim().isEmpty ? null : number(planned.text);
    final quantity = actual.text.trim().isEmpty ? null : number(actual.text);
    final people = <Map<String, dynamic>>[];
    String? invalid;
    if (planned.text.trim().isNotEmpty && !valid(plan)) invalid = 'Проверьте плановый объём';
    if (actual.text.trim().isNotEmpty && !valid(quantity)) invalid = 'Проверьте фактический объём';
    if ((plan != null || quantity != null) && unit.text.trim().isEmpty) invalid = 'Укажите единицу измерения';
    if (quantity != null) {
      for (final id in selected) {
        final weight = number(ktu[id]!.text);
        if (!valid(weight) || weight == null || weight > 10000) { invalid = 'КТУ должен быть от 0 до 10000%'; break; }
        people.add({'employee_id': id, 'ktu': weight});
      }
      if (people.isEmpty || people.every((p) => (p['ktu'] as num) == 0)) {
        invalid = 'Отметьте исполнителей и укажите положительный КТУ';
      }
    }
    if (invalid != null) { setState(() => error = invalid); return false; }
    setState(() { busy = true; error = null; });
    try {
      await WorkOrderRepository.save(taskId: widget.taskId, planned: plan,
          unit: unit.text.trim(), date: date, quantity: quantity, participants: people);
      await load();
      if (mounted && notify) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Объём и наряд сохранены')));
      return true;
    } catch (e) {
      if (mounted) setState(() => error = 'Не удалось сохранить. Проверьте интернет и синхронизацию задачи. $e');
      return false;
    } finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> deleteDay() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Удалить факт за день?'),
      content: Text('Запись за ${DateFormat('dd.MM.yyyy').format(date)} исчезнет из наряда.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить'))],
    ));
    if (confirmed != true || !mounted) return;
    setState(() { busy = true; error = null; });
    try { await WorkOrderRepository.deleteDay(widget.taskId, date); await load(); }
    catch (e) { if (mounted) setState(() => error = 'Не удалось удалить: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Widget field(TextEditingController controller, String label, {bool numeric = true}) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: TextField(
        controller: controller, enabled: widget.canEdit && !busy,
        keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ));
  @override
  Widget build(BuildContext context) {
    final total = days.fold<double>(0, (sum, day) => sum + (day['quantity'] as num).toDouble());
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Объём и наряд', style: Theme.of(context).textTheme.titleMedium),
      if (loading) const LinearProgressIndicator() else ...[
        field(planned, 'Плановый объём задачи'), field(unit, 'Единица измерения (м³, м², т, шт.)', numeric: false),
        Text('Всего сохранено по дням: ${total.toStringAsFixed(3)} ${unit.text}'),
        if (days.isNotEmpty) Wrap(spacing: 6, children: [
          for (final day in days) ActionChip(
            label: Text('${DateFormat('dd.MM').format(DateTime.parse(day['work_date'] as String))}: ${day['quantity']}'),
            onPressed: busy ? null : () => changeDay(DateTime.parse(day['work_date'] as String)),
          ),
        ]),
        OutlinedButton.icon(onPressed: busy ? null : pickDate, icon: const Icon(Icons.calendar_month),
            label: Text('Факт за ${DateFormat('dd.MM.yyyy').format(date)}')),
        field(actual, 'Выполненный объём за этот день'),
        const Text('КТУ 100% — обычное участие. Общий объём распределяется пропорционально КТУ.'),
        for (final id in names.keys) Row(children: [
          Checkbox(value: selected.contains(id), onChanged: !widget.canEdit || busy ? null : (value) => setState(() {
            if (value == true) { selected.add(id); } else { selected.remove(id); }
          })),
          Expanded(child: Text(names[id]!)),
          const SizedBox(width: 8), SizedBox(width: 95, child: field(ktu[id]!, 'КТУ, %')),
        ]),
        if (names.isEmpty) const Text('Сначала сохраните исполнителей задачи, затем откройте её снова.'),
        if (widget.canEdit) ...[
          FilledButton(onPressed: busy ? null : () => save(), child: Text(busy ? 'Сохранение…' : 'Сохранить объём и КТУ')),
          if (days.any((d) => d['work_date'] == WorkOrderRepository.dateKey(date)))
            TextButton(onPressed: busy ? null : deleteDay, child: const Text('Удалить факт за этот день')),
        ],
      ],
      if (error != null) ...[Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        TextButton(onPressed: busy ? null : load, child: const Text('Повторить загрузку'))],
    ])));
  }
}
