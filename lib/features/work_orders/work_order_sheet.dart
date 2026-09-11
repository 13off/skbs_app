import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'work_order_exporter.dart';
import 'work_order_repository.dart';

Future<void> showWorkOrderSheet(BuildContext context, {String? objectName,
    DateTime? initialDate}) => showModalBottomSheet<void>(
  context: context, isScrollControlled: true, useSafeArea: true,
  showDragHandle: true,
  builder: (_) => WorkOrderSheet(objectName: objectName,
      initialDate: initialDate ?? DateTime.now()),
);

class WorkOrderSheet extends StatefulWidget {
  const WorkOrderSheet({super.key, this.objectName, required this.initialDate});
  final String? objectName;
  final DateTime initialDate;
  @override
  State<WorkOrderSheet> createState() => _WorkOrderSheetState();
}

class _WorkOrderSheetState extends State<WorkOrderSheet> {
  late DateTime start;
  late DateTime end;
  bool choosingEnd = false;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    start = DateUtils.dateOnly(widget.initialDate);
    end = start;
  }

  Future<void> download() async {
    setState(() { busy = true; error = null; });
    try {
      final rows = await WorkOrderRepository.period(start, end, widget.objectName);
      if (rows.isEmpty) {
        if (mounted) setState(() => error =
            'За этот период нет сохранённого объёма. Укажите факт в задаче в блоке «Объём и наряд».');
        return;
      }
      await WorkOrderExporter.save(rows, start, end, widget.objectName);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = 'Не удалось скачать наряд: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd.MM.yyyy');
    return FractionallySizedBox(heightFactor: .92, child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Скачать наряд', style: Theme.of(context).textTheme.headlineSmall),
        Text(widget.objectName ?? 'Все доступные объекты'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          ChoiceChip(label: Text('С ${format.format(start)}'), selected: !choosingEnd,
              onSelected: busy ? null : (_) => setState(() => choosingEnd = false)),
          ChoiceChip(label: Text('По ${format.format(end)}'), selected: choosingEnd,
              onSelected: busy ? null : (_) => setState(() => choosingEnd = true)),
          ActionChip(label: const Text('Сегодня'), onPressed: busy ? null : () => setState(() {
            start = DateUtils.dateOnly(DateTime.now()); end = start; choosingEnd = false;
          })),
        ]),
        Text(choosingEnd ? 'Выберите последний день периода' : 'Выберите первый день. Для одного дня оставьте даты одинаковыми.'),
        IgnorePointer(ignoring: busy, child: CalendarDatePicker(
          key: ValueKey('${choosingEnd}_${start.toIso8601String()}_${end.toIso8601String()}'),
          initialDate: choosingEnd ? end : start,
          firstDate: DateTime(2000), lastDate: DateTime(2100),
          onDateChanged: (date) => setState(() {
            if (choosingEnd) {
              if (date.isBefore(start)) { end = start; start = date; }
              else { end = date; }
            } else { start = date; end = date; choosingEnd = true; }
            error = null;
          }),
        )),
        Text('Период: ${format.format(start)} — ${format.format(end)}'),
        if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: busy ? null : download,
            icon: busy ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download),
            label: Text(busy ? 'Формирование…' : 'Скачать Excel')),
      ]),
    ));
  }
}
