import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../models/task_item_data.dart';
import '../data/task_completion_report_repository.dart';
import '../models/task_completion_report.dart';

Future<bool> showTaskCompletionReportDialog({
  required BuildContext context,
  required TaskItemData task,
  TaskCompletionReport? existing,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _TaskCompletionReportDialog(
          task: task,
          existing: existing,
        ),
      ) ??
      false;
}

class _TaskCompletionReportDialog extends StatefulWidget {
  final TaskItemData task;
  final TaskCompletionReport? existing;

  const _TaskCompletionReportDialog({
    required this.task,
    required this.existing,
  });

  @override
  State<_TaskCompletionReportDialog> createState() =>
      _TaskCompletionReportDialogState();
}

class _TaskCompletionReportDialogState
    extends State<_TaskCompletionReportDialog> {
  late final TextEditingController quantityController;
  late final TextEditingController unitController;
  late final TextEditingController locationController;
  late final TextEditingController commentController;
  bool saving = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    quantityController = TextEditingController(
      text: existing?.reportedQuantity == null
          ? ''
          : TaskCompletionReport.formatQuantity(existing!.reportedQuantity!),
    );
    unitController = TextEditingController(text: existing?.unit ?? '');
    locationController = TextEditingController(
      text: existing?.workLocation.trim().isNotEmpty == true
          ? existing!.workLocation
          : widget.task.axes,
    );
    commentController = TextEditingController(
      text: existing?.completionComment ?? '',
    );
  }

  @override
  void dispose() {
    quantityController.dispose();
    unitController.dispose();
    locationController.dispose();
    commentController.dispose();
    super.dispose();
  }

  double? parseQuantity() {
    final raw = quantityController.text.trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw.replaceAll(',', '.'));
  }

  Future<void> submit() async {
    if (saving) return;
    final quantityText = quantityController.text.trim();
    final quantity = parseQuantity();
    final unit = unitController.text.trim();

    if (quantityText.isNotEmpty && (quantity == null || quantity <= 0)) {
      setState(() => errorText = 'Укажите корректный фактический объём');
      return;
    }
    if (quantity != null && unit.isEmpty) {
      setState(() => errorText = 'Для объёма укажите единицу измерения');
      return;
    }

    setState(() {
      saving = true;
      errorText = null;
    });
    try {
      await TaskCompletionReportRepository.submit(
        taskId: widget.task.id!,
        reportedQuantity: quantity,
        unit: unit,
        workLocation: locationController.text,
        completionComment: commentController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => errorText = error.toString().replaceFirst('PostgrestException(message: ', ''),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final returned = widget.existing?.isReturned == true;
    return AlertDialog(
      title: Text(returned ? 'Исправить выполненную работу' : 'Результат выполнения'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppAdaptivePalette.surfaceSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppAdaptivePalette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.task.work,
                      style: TextStyle(
                        color: AppAdaptivePalette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [widget.task.objectName, widget.task.axes]
                          .where((value) => value.trim().isNotEmpty)
                          .join(' · '),
                      style: TextStyle(
                        color: AppAdaptivePalette.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (returned) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppAdaptivePalette.surfaceSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppAdaptivePalette.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.reply_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Возвращено инженером-сметчиком',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text(widget.existing!.reviewComment),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: quantityController,
                      enabled: !saving,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Фактический объём',
                        hintText: 'Можно оставить пустым',
                        prefixIcon: Icon(Icons.straighten_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: unitController,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: 'Единица измерения',
                        hintText: 'м³, м², т, м.п., шт.',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: 'Участок / этаж / оси / захватка',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                enabled: !saving,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Комментарий мастера',
                  hintText: 'Что именно выполнено, отклонения, особенности',
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
              const SizedBox(height: 10),
              Text(
                'Задача уже считается выполненной. Здесь мастер фиксирует факт для отдельной проверки инженером-сметчиком.',
                style: TextStyle(
                  color: AppAdaptivePalette.textMuted,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('Позже'),
        ),
        FilledButton.icon(
          onPressed: saving ? null : submit,
          icon: saving
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded),
          label: const Text('Передать инженеру-сметчику'),
        ),
      ],
    );
  }
}
