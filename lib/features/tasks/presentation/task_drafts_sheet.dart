import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../models/task_item_data.dart';

Future<TaskItemData?> showTaskDraftsSheet({
  required BuildContext context,
  required List<TaskItemData> drafts,
  required Future<void> Function(TaskItemData draft) onDelete,
}) {
  final visibleDrafts = List<TaskItemData>.from(drafts);
  return showModalBottomSheet<TaskItemData>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 620),
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              decoration: BoxDecoration(
                color: AppAdaptivePalette.surfaceElevated,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppAdaptivePalette.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppAdaptivePalette.border,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Черновики задач',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Черновики видны только создавшему их прорабу.',
                    style: TextStyle(
                      color: AppAdaptivePalette.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (visibleDrafts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'Сохранённых черновиков нет',
                          style: TextStyle(
                            color: AppAdaptivePalette.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: visibleDrafts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final draft = visibleDrafts[index];
                          final work = draft.work.trim().isEmpty
                              ? 'Без названия'
                              : draft.work.trim();
                          final axes = draft.axes.trim().isEmpty
                              ? 'Оси не указаны'
                              : 'Оси: ${draft.axes.trim()}';
                          final date =
                              '${draft.date.day.toString().padLeft(2, '0')}.${draft.date.month.toString().padLeft(2, '0')}.${draft.date.year}';
                          return Material(
                            color: AppAdaptivePalette.surfaceSoft,
                            borderRadius: BorderRadius.circular(18),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                                side: BorderSide(
                                  color: AppAdaptivePalette.border,
                                ),
                              ),
                              leading: const Icon(Icons.drafts_outlined),
                              title: Text(
                                work,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text('$axes · $date'),
                              onTap: () => Navigator.pop(sheetContext, draft),
                              trailing: IconButton(
                                tooltip: 'Удалить черновик',
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppAdaptivePalette.danger,
                                ),
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: sheetContext,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Удалить черновик?'),
                                      content: Text(work),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Отмена'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Удалить'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed != true) return;
                                  await onDelete(draft);
                                  visibleDrafts.removeWhere(
                                    (item) => item.id == draft.id,
                                  );
                                  setSheetState(() {});
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
