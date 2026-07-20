import 'package:flutter/material.dart';

import '../data/task_progress_repository.dart';
import '../models/app_user_profile.dart';
import '../models/task_item_data.dart';
import 'task_details/task_details_editor_screen.dart' as editor;

/// Публичный слой дополняет редактор задачи учётом дневного прогресса.
class TaskDetailsScreen extends StatefulWidget {
  final TaskItemData task;
  final AppUserProfile profile;

  const TaskDetailsScreen({
    super.key,
    required this.task,
    required this.profile,
  });

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  bool started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => openEditor());
  }

  Future<void> openEditor() async {
    if (started || !mounted) return;
    started = true;

    var currentTask = widget.task;
    final taskId = widget.task.id?.trim() ?? '';
    final originalLink = taskId.isEmpty
        ? null
        : await TaskProgressRepository.fetchCurrentLink(taskId);
    final previousChecklistItemId = originalLink?.checklistItemId;

    while (mounted) {
      final result = await Navigator.of(context).push<dynamic>(
        MaterialPageRoute<dynamic>(
          builder: (_) => editor.TaskDetailsScreen(
            task: currentTask,
            profile: widget.profile,
          ),
        ),
      );

      if (!mounted) return;
      if (result == null || result == 'delete') {
        Navigator.of(context).pop(result);
        return;
      }
      if (result is! TaskItemData) {
        Navigator.of(context).pop(result);
        return;
      }

      currentTask = result;
      try {
        final linked = _isLinked(result);
        if (result.status == 'Выполнено' && linked) {
          final progressContext = await TaskProgressRepository.fetchContext(
            taskId: result.id!,
            checklistItemId: result.checklistItemId!,
          );
          if (!mounted) return;

          final selectedPercent = await showDialog<int>(
            context: context,
            barrierDismissible: false,
            builder: (_) => _DailyProgressDialog(
              contextData: progressContext,
            ),
          );
          if (!mounted) return;

          if (selectedPercent == null) {
            continue;
          }

          await TaskProgressRepository.saveCompletedTask(
            task: result,
            progressPercent: selectedPercent,
            previousChecklistItemId: previousChecklistItemId,
          );
        } else {
          await TaskProgressRepository.saveWithoutCompletion(
            task: result,
            previousChecklistItemId: previousChecklistItemId,
          );
        }

        if (!mounted) return;
        Navigator.of(context).pop(result);
        return;
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить прогресс: $error')),
        );
      }
    }
  }

  bool _isLinked(TaskItemData task) {
    final milestoneId = task.milestoneId?.trim() ?? '';
    final checklistItemId = task.checklistItemId?.trim() ?? '';
    return (task.id?.trim() ?? '').isNotEmpty &&
        milestoneId.isNotEmpty &&
        checklistItemId.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _DailyProgressDialog extends StatefulWidget {
  final TaskProgressContext contextData;

  const _DailyProgressDialog({required this.contextData});

  @override
  State<_DailyProgressDialog> createState() => _DailyProgressDialogState();
}

class _DailyProgressDialogState extends State<_DailyProgressDialog> {
  late int selectedPercent;

  @override
  void initState() {
    super.initState();
    selectedPercent = widget.contextData.ownProgressPercent
        .clamp(0, widget.contextData.maxAllowedPercent)
        .toInt();
  }

  int get maxAllowed => widget.contextData.maxAllowedPercent;

  int get projectedProgress {
    final restoredOwn = widget.contextData.ownProgressIsCounted
        ? widget.contextData.ownProgressPercent
        : 0;
    return (widget.contextData.itemProgressPercent -
            restoredOwn +
            selectedPercent)
        .clamp(0, 100)
        .toInt();
  }

  void confirm() {
    if (maxAllowed > 0 && selectedPercent <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Укажи, сколько процентов выполнено сегодня'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(selectedPercent);
  }

  @override
  Widget build(BuildContext context) {
    final sliderMax = maxAllowed <= 0 ? 1.0 : maxAllowed.toDouble();
    final sliderValue = selectedPercent.clamp(0, maxAllowed).toDouble();
    final quickValues = <int>{10, 20, 25, 30, 50, maxAllowed}
        .where((value) => value > 0 && value <= maxAllowed)
        .toList()
      ..sort();

    return AlertDialog(
      title: const Text('Что выполнили сегодня?'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.contextData.checklistTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Накоплено по пункту: '
              '${widget.contextData.itemProgressPercent}% из 100%.',
              style: const TextStyle(color: Color(0xFF6B7075)),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    min: 0,
                    max: sliderMax,
                    divisions: maxAllowed <= 0 ? 1 : maxAllowed,
                    value: sliderValue,
                    onChanged: maxAllowed <= 0
                        ? null
                        : (value) {
                            setState(() => selectedPercent = value.round());
                          },
                  ),
                ),
                SizedBox(
                  width: 82,
                  child: Text(
                    '+$selectedPercent%',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            if (quickValues.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: quickValues.map((value) {
                  return ChoiceChip(
                    label: Text('+$value%'),
                    selected: selectedPercent == value,
                    onSelected: (_) {
                      setState(() => selectedPercent = value);
                    },
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                maxAllowed <= 0
                    ? 'Этот пункт уже выполнен на 100%.'
                    : 'После сохранения будет $projectedProgress%. '
                        'Максимум для этой задачи: $maxAllowed%.',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
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
          label: const Text('Сохранить выполнение'),
        ),
      ],
    );
  }
}
