import 'package:flutter/material.dart';

import '../app/app_adaptive_palette.dart';
import '../data/task_assignee_repository.dart';
import '../data/task_progress_repository.dart';
import '../features/estimator/data/task_completion_report_repository.dart';
import '../features/estimator/presentation/task_completion_report_dialog.dart';
import '../features/tasks/presentation/task_contribution_dialog.dart';
import '../features/work_orders/work_order_repository.dart';
import '../models/app_user_profile.dart';
import '../models/task_item_data.dart';
import 'task_details/task_details_editor_screen.dart' as editor;

/// Публичный слой дополняет редактор задачи учётом дневного прогресса
/// и фактического объёма/КТУ исполнителей при завершении.
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
    // Start the progress lookup immediately, but never hold the route opening
    // behind the network. The result is only needed when the edited task is
    // saved.
    final previousChecklistItemFuture = _fetchPreviousChecklistItemId(taskId);

    while (mounted) {
      final previousTask = currentTask;
      final result = await Navigator.of(context).push<dynamic>(
        PageRouteBuilder<dynamic>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => editor.TaskDetailsScreen(
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
        final previousChecklistItemId = await previousChecklistItemFuture;
        final linked = _isLinked(result);
        TaskCompletionWorkResult? completionWork;
        double? plannedQuantity;
        String? workUnit;

        final newlyCompleted =
            result.status == 'Выполнено' && previousTask.status != 'Выполнено';
        if (newlyCompleted) {
          final assignees = await TaskAssigneeRepository.fetchAssignees(
            result.id!,
          );
          if (!mounted) return;
          if (assignees.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Чтобы завершить задачу, добавьте хотя бы одного исполнителя',
                ),
              ),
            );
            continue;
          }

          final plan = await WorkOrderRepository.plan(result.id!);
          if (!mounted) return;
          final rawPlan = plan?['planned_quantity'];
          plannedQuantity = rawPlan is num
              ? rawPlan.toDouble()
              : double.tryParse(rawPlan?.toString() ?? '');
          workUnit = plan?['unit']?.toString().trim() ?? '';
          if (plannedQuantity == null ||
              !plannedQuantity.isFinite ||
              plannedQuantity <= 0 ||
              workUnit.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Сначала укажите плановый объём и единицу измерения в блоке «Объём и наряд»',
                ),
              ),
            );
            continue;
          }

          completionWork = await showTaskContributionDialog(
            context: context,
            entries: <TaskKtuEntry>[
              for (final assignee in assignees)
                TaskKtuEntry(
                  employeeId: assignee.employeeId,
                  employeeName: assignee.employeeName,
                  position: assignee.position,
                ),
            ],
            unitLabel: workUnit,
            plannedQuantity: plannedQuantity,
          );
          if (!mounted) return;
          if (completionWork == null) continue;
        }

        int? selectedProgress;
        if (result.status == 'Выполнено' && linked) {
          final progressContext = await TaskProgressRepository.fetchContext(
            taskId: result.id!,
            checklistItemId: result.checklistItemId!,
          );
          if (!mounted) return;

          selectedProgress = await showDialog<int>(
            context: context,
            barrierDismissible: false,
            builder: (_) => _DailyProgressDialog(contextData: progressContext),
          );
          if (!mounted) return;
          if (selectedProgress == null) continue;
        }

        // Persist the work-order fact before changing the operational status:
        // a task must never become completed without its actual volume and KTU.
        if (completionWork != null) {
          await WorkOrderRepository.save(
            taskId: result.id!,
            planned: plannedQuantity,
            unit: workUnit!,
            date: result.date,
            quantity: completionWork.actualVolume,
            participants: <Map<String, dynamic>>[
              for (final entry in completionWork.participants)
                <String, dynamic>{
                  'employee_id': entry.employeeId,
                  'ktu': entry.ktu,
                },
            ],
          );
        }

        if (result.status == 'Выполнено' && linked) {
          await TaskProgressRepository.saveCompletedTask(
            task: result,
            progressPercent: selectedProgress!,
            previousChecklistItemId: previousChecklistItemId,
          );
        } else {
          await TaskProgressRepository.saveWithoutCompletion(
            task: result,
            previousChecklistItemId: previousChecklistItemId,
          );
        }

        if (result.status == 'Выполнено') {
          await _offerEstimatorSubmission(result);
        } else if (previousTask.status == 'Выполнено') {
          // Reopening removes the completion fact so the work order cannot keep
          // reporting a task that is no longer completed.
          await WorkOrderRepository.deleteDay(result.id!, previousTask.date);
        }

        if (!mounted) return;
        Navigator.of(context).pop(result);
        return;
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить выполнение: $error')),
        );
      }
    }
  }

  Future<void> _offerEstimatorSubmission(TaskItemData task) async {
    if (!mounted || (task.id?.trim() ?? '').isEmpty) return;
    try {
      final existing = await TaskCompletionReportRepository.fetchForTask(
        task.id!,
      );
      if (!mounted) return;
      if (existing != null && !existing.isReturned) return;

      final submitted = await showTaskCompletionReportDialog(
        context: context,
        task: task,
        existing: existing,
      );
      if (!mounted || !submitted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выполненная работа передана инженеру-сметчику'),
        ),
      );
    } catch (error) {
      // The operational task is already saved. Estimator transport is an
      // additional contour and must never roll the task completion back.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Задача сохранена, но факт не удалось передать сметчику: $error',
          ),
        ),
      );
    }
  }

  Future<String?> _fetchPreviousChecklistItemId(String taskId) async {
    if (taskId.isEmpty) return null;
    try {
      final originalLink = await TaskProgressRepository.fetchCurrentLink(
        taskId,
      );
      return originalLink?.checklistItemId;
    } catch (_) {
      // Opening and editing the task must remain available even when the
      // optional progress link is temporarily unavailable.
      return null;
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
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
    final quickValues = <int>{
      10,
      20,
      25,
      30,
      50,
      maxAllowed,
    }.where((value) => value > 0 && value <= maxAllowed).toList()..sort();

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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              'Накоплено по пункту: '
              '${widget.contextData.itemProgressPercent}% из 100%.',
              style: TextStyle(color: AppAdaptivePalette.textMuted),
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
                color: AppAdaptivePalette.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppAdaptivePalette.border),
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
