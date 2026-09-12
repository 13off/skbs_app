import 'package:flutter/material.dart';
import 'package:skbs_app/widgets/app_input_formatters.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../data/object_repository.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/estimator_manual_volume_repository.dart';
import '../models/estimator_manual_volume.dart';
import '../models/task_completion_report.dart';

class EstimatorManualVolumesScreen extends StatefulWidget {
  const EstimatorManualVolumesScreen({super.key});

  @override
  State<EstimatorManualVolumesScreen> createState() =>
      _EstimatorManualVolumesScreenState();
}

class _EstimatorManualVolumesScreenState
    extends State<EstimatorManualVolumesScreen> {
  late Future<List<EstimatorManualVolume>> future;
  String filter = 'active';

  @override
  void initState() {
    super.initState();
    future = EstimatorManualVolumeRepository.fetchAll();
  }

  Future<void> refresh() async {
    final next = EstimatorManualVolumeRepository.fetchAll();
    if (mounted) setState(() => future = next);
    await next;
  }

  List<EstimatorManualVolume> filtered(List<EstimatorManualVolume> items) {
    switch (filter) {
      case 'voided':
        return items.where((item) => item.isVoided).toList(growable: false);
      case 'all':
        return items;
      default:
        return items.where((item) => !item.isVoided).toList(growable: false);
    }
  }

  String dateTitle(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  Future<void> addManualVolume() async {
    final objects = await ObjectRepository.fetchObjectNames();
    if (!mounted) return;
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ManualVolumeDialog(objects: objects),
    );
    if (created == true && mounted) await refresh();
  }

  Future<void> voidRecord(EstimatorManualVolume item) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Аннулировать ручной объём?'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${item.work} · ${TaskCompletionReport.formatQuantity(item.quantity)} ${item.unit}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              TextField(
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: AppInputFormatters.sentences,
                controller: controller,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Причина аннулирования',
                  hintText: 'Обязательно укажите, почему запись исключается',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Аннулировать'),
          ),
        ],
      ),
    );
    final reason = controller.text.trim();
    controller.dispose();
    if (confirmed != true || reason.isEmpty) return;

    try {
      await EstimatorManualVolumeRepository.voidRecord(
        id: item.id,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ручной объём аннулирован')),
      );
      await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось аннулировать запись: $error')),
      );
    }
  }

  Widget metric(String label, int value, IconData icon) {
    return SizedBox(
      width: 200,
      child: PremiumWorkCard(
        radius: 22,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppAdaptivePalette.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppAdaptivePalette.textPrimary),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    color: AppAdaptivePalette.textPrimary,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget recordCard(EstimatorManualVolume item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumWorkCard(
        radius: 22,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppAdaptivePalette.surfaceSoft,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Text(
                              'Вручную',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (item.isVoided) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF985A51).withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: const Text(
                                'Аннулировано',
                                style: TextStyle(
                                  color: Color(0xFFB36C61),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.work,
                        style: TextStyle(
                          color: AppAdaptivePalette.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          decoration: item.isVoided
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.objectName} · ${dateTitle(item.workDate)}',
                        style: TextStyle(
                          color: AppAdaptivePalette.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${TaskCompletionReport.formatQuantity(item.quantity)} ${item.unit}',
                  style: TextStyle(
                    color: AppAdaptivePalette.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppAdaptivePalette.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.reasonTitle,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(item.reasonComment),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Добавил: ${item.createdByName.trim().isEmpty ? 'не указано' : item.createdByName} · ${dateTitle(item.createdAt)}',
                    style: TextStyle(
                      color: AppAdaptivePalette.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (!item.isVoided)
                  TextButton.icon(
                    onPressed: () => voidRecord(item),
                    icon: const Icon(Icons.block_rounded),
                    label: const Text('Аннулировать'),
                  ),
              ],
            ),
            if (item.isVoided) ...[
              const SizedBox(height: 8),
              Text(
                'Аннулировал: ${item.voidedByName.trim().isEmpty ? 'не указано' : item.voidedByName}. Причина: ${item.voidReason}',
                style: const TextStyle(
                  color: Color(0xFFB36C61),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Ручные объёмы',
      subtitle: 'Исключения, которые не пришли из задач мастеров',
      onRefresh: refresh,
      headerTrailing: FilledButton.icon(
        onPressed: addManualVolume,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Добавить объём'),
      ),
      child: FutureBuilder<List<EstimatorManualVolume>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return SizedBox(
              height: 220,
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Не удалось загрузить · Повторить'),
                ),
              ),
            );
          }

          final all = snapshot.data ?? const <EstimatorManualVolume>[];
          final activeCount = all.where((item) => !item.isVoided).length;
          final voidedCount = all.where((item) => item.isVoided).length;
          final items = filtered(all);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppAdaptivePalette.surfaceSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppAdaptivePalette.border),
                ),
                child: Text(
                  'Ручной объём — исключение. Причина и пояснение обязательны. '
                  'Запись нельзя удалить: её можно только аннулировать с причиной. '
                  'Активные ручные записи автоматически входят в накопительную «Объёмы».',
                  style: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  metric('Активных', activeCount, Icons.edit_note_rounded),
                  metric('Аннулировано', voidedCount, Icons.block_rounded),
                  metric('Всего записей', all.length, Icons.history_rounded),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Активные'),
                    selected: filter == 'active',
                    onSelected: (_) => setState(() => filter = 'active'),
                  ),
                  ChoiceChip(
                    label: const Text('Аннулированные'),
                    selected: filter == 'voided',
                    onSelected: (_) => setState(() => filter = 'voided'),
                  ),
                  ChoiceChip(
                    label: const Text('Все'),
                    selected: filter == 'all',
                    onSelected: (_) => setState(() => filter = 'all'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (items.isEmpty)
                PremiumWorkCard(
                  radius: 22,
                  padding: const EdgeInsets.all(26),
                  child: Center(
                    child: Text(
                      filter == 'active'
                          ? 'Активных ручных объёмов нет'
                          : 'В этом разделе пока пусто',
                      style: TextStyle(
                        color: AppAdaptivePalette.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                )
              else
                ...items.map(recordCard),
            ],
          );
        },
      ),
    );
  }
}

class _ManualVolumeDialog extends StatefulWidget {
  final List<String> objects;

  const _ManualVolumeDialog({required this.objects});

  @override
  State<_ManualVolumeDialog> createState() => _ManualVolumeDialogState();
}

class _ManualVolumeDialogState extends State<_ManualVolumeDialog> {
  static const _units = <String>[
    'м³',
    'м²',
    'м.п.',
    'т',
    'кг',
    'шт.',
    'компл.',
    'Другое',
  ];
  static const _reasons = <(String, String)>[
    ('unplanned_work', 'Дополнительная работа'),
    ('task_missing', 'Работа без задачи'),
    ('correction', 'Корректировка объёма'),
    ('carryover', 'Перенос из другого периода'),
    ('other', 'Другое'),
  ];

  final workController = TextEditingController();
  final quantityController = TextEditingController();
  final customUnitController = TextEditingController();
  final commentController = TextEditingController();
  String objectName = '';
  String unit = 'м³';
  String reasonCode = 'task_missing';
  DateTime workDate = DateTime.now();
  bool saving = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    if (widget.objects.isNotEmpty) objectName = widget.objects.first;
  }

  @override
  void dispose() {
    workController.dispose();
    quantityController.dispose();
    customUnitController.dispose();
    commentController.dispose();
    super.dispose();
  }

  double? quantity() {
    return AppInputFormatters.tryParseDouble(quantityController.text);
  }

  String get effectiveUnit =>
      unit == 'Другое' ? customUnitController.text.trim() : unit;

  String dateTitle(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  Future<void> chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: workDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => workDate = picked);
  }

  Future<void> save() async {
    if (saving) return;
    final value = quantity();
    if (objectName.trim().isEmpty) {
      setState(() => errorText = 'Выберите объект');
      return;
    }
    if (workController.text.trim().isEmpty) {
      setState(() => errorText = 'Укажите наименование работы');
      return;
    }
    if (value == null || value <= 0) {
      setState(() => errorText = 'Укажите корректный объём');
      return;
    }
    if (effectiveUnit.isEmpty) {
      setState(() => errorText = 'Укажите единицу измерения');
      return;
    }
    if (commentController.text.trim().isEmpty) {
      setState(() => errorText = 'Объясните причину ручного ввода');
      return;
    }

    setState(() {
      saving = true;
      errorText = null;
    });
    try {
      await EstimatorManualVolumeRepository.create(
        objectName: objectName,
        work: workController.text,
        unit: effectiveUnit,
        quantity: value,
        workDate: workDate,
        reasonCode: reasonCode,
        reasonComment: commentController.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => errorText = '$error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить объём вручную'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.objects.isEmpty)
                const Text(
                  'В компании пока нет активных объектов. Сначала создайте объект.',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: objectName,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Объект',
                    prefixIcon: Icon(Icons.apartment_rounded),
                  ),
                  items: widget.objects
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item,
                          child: Text(
                            item,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: saving
                      ? null
                      : (value) => setState(() => objectName = value ?? ''),
                ),
              const SizedBox(height: 12),
              TextField(
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: AppInputFormatters.sentences,
                controller: workController,
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: 'Наименование работы',
                  prefixIcon: Icon(Icons.construction_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: quantityController,
                      enabled: !saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: AppInputFormatters.groupedNumber,
                      decoration: const InputDecoration(
                        labelText: 'Объём',
                        prefixIcon: Icon(Icons.straighten_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: unit,
                      decoration: const InputDecoration(
                        labelText: 'Единица',
                      ),
                      items: _units
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: saving
                          ? null
                          : (value) => setState(() => unit = value ?? 'м³'),
                    ),
                  ),
                ],
              ),
              if (unit == 'Другое') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: customUnitController,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'Своя единица измерения',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: saving ? null : chooseDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('Дата выполнения: ${dateTitle(workDate)}'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: reasonCode,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Причина ручного ввода',
                  prefixIcon: Icon(Icons.rule_rounded),
                ),
                items: _reasons
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.$1,
                        child: Text(item.$2),
                      ),
                    )
                    .toList(growable: false),
                onChanged: saving
                    ? null
                    : (value) => setState(
                        () => reasonCode = value ?? 'task_missing',
                      ),
              ),
              const SizedBox(height: 12),
              TextField(
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: AppInputFormatters.sentences,
                controller: commentController,
                enabled: !saving,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Пояснение',
                  hintText: 'Почему объём добавляется вручную и чем подтверждается',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorText!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        FilledButton.icon(
          onPressed: saving || widget.objects.isEmpty ? null : save,
          icon: saving
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_rounded),
          label: const Text('Добавить в объёмы'),
        ),
      ],
    );
  }
}
