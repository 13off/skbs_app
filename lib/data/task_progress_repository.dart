import 'package:supabase_flutter/supabase_flutter.dart';

import 'task_repository.dart';
import '../models/task_item_data.dart';

class TaskProgressContext {
  final String checklistTitle;
  final int itemProgressPercent;
  final int ownProgressPercent;
  final bool ownProgressIsCounted;

  const TaskProgressContext({
    required this.checklistTitle,
    required this.itemProgressPercent,
    required this.ownProgressPercent,
    required this.ownProgressIsCounted,
  });

  int get maxAllowedPercent {
    final restoredOwn = ownProgressIsCounted ? ownProgressPercent : 0;
    return (100 - itemProgressPercent + restoredOwn).clamp(0, 100).toInt();
  }
}

abstract final class TaskProgressRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static int _cleanPercent(Object? value) {
    return ((value as num?)?.toInt() ?? 0).clamp(0, 100).toInt();
  }

  static Future<TaskProgressContext> fetchContext({
    required String taskId,
    required String checklistItemId,
  }) async {
    final itemRow = await _client
        .from('milestone_checklist_items')
        .select('title')
        .eq('id', checklistItemId)
        .single();

    final rawLinks = await _client
        .from('task_milestone_links')
        .select('task_id, progress_percent, tasks(status)')
        .eq('checklist_item_id', checklistItemId);

    var total = 0;
    var ownProgress = 0;
    var ownIsCounted = false;

    for (final raw in rawLinks) {
      final row = Map<String, dynamic>.from(raw);
      final linkedTaskId = row['task_id']?.toString() ?? '';
      final progress = _cleanPercent(row['progress_percent']);
      final taskRaw = row['tasks'];
      final task = taskRaw is Map ? Map<String, dynamic>.from(taskRaw) : null;
      final isDone = task?['status']?.toString() == 'Выполнено';

      if (isDone) total += progress;
      if (linkedTaskId == taskId) {
        ownProgress = progress;
        ownIsCounted = isDone;
      }
    }

    return TaskProgressContext(
      checklistTitle: itemRow['title']?.toString() ?? 'Пункт чек-листа',
      itemProgressPercent: total.clamp(0, 100).toInt(),
      ownProgressPercent: ownProgress,
      ownProgressIsCounted: ownIsCounted,
    );
  }

  static Future<TaskMilestoneLinkData?> fetchCurrentLink(String taskId) {
    return TaskRepository.fetchTaskMilestoneLink(taskId);
  }

  static Future<void> saveCompletedTask({
    required TaskItemData task,
    required int progressPercent,
    required String? previousChecklistItemId,
  }) async {
    final taskId = task.id?.trim() ?? '';
    final milestoneId = task.milestoneId?.trim() ?? '';
    final checklistItemId = task.checklistItemId?.trim() ?? '';
    if (taskId.isEmpty || milestoneId.isEmpty || checklistItemId.isEmpty) {
      throw Exception('Задача не привязана к цели и пункту чек-листа');
    }

    await _client.from('task_milestone_links').upsert(
      {
        'task_id': taskId,
        'milestone_id': milestoneId,
        'checklist_item_id': checklistItemId,
        'progress_percent': progressPercent.clamp(0, 100).toInt(),
      },
      onConflict: 'task_id',
    );

    await TaskRepository.updateTask(task);
    await _recalculateItem(checklistItemId);

    final previous = previousChecklistItemId?.trim() ?? '';
    if (previous.isNotEmpty && previous != checklistItemId) {
      await _recalculateItem(previous);
    }
  }

  static Future<void> saveWithoutCompletion({
    required TaskItemData task,
    required String? previousChecklistItemId,
  }) async {
    final selectedItem = task.checklistItemId?.trim() ?? '';
    final previousItem = previousChecklistItemId?.trim() ?? '';

    if (selectedItem.isNotEmpty && selectedItem != previousItem) {
      final taskId = task.id?.trim() ?? '';
      final milestoneId = task.milestoneId?.trim() ?? '';
      if (taskId.isNotEmpty && milestoneId.isNotEmpty) {
        await _client.from('task_milestone_links').upsert(
          {
            'task_id': taskId,
            'milestone_id': milestoneId,
            'checklist_item_id': selectedItem,
            'progress_percent': 0,
          },
          onConflict: 'task_id',
        );
      }
    }

    await TaskRepository.updateTask(task);

    if (previousItem.isNotEmpty) await _recalculateItem(previousItem);
    if (selectedItem.isNotEmpty && selectedItem != previousItem) {
      await _recalculateItem(selectedItem);
    }
  }

  static Future<void> _recalculateItem(String checklistItemId) async {
    final itemRow = await _client
        .from('milestone_checklist_items')
        .select('state')
        .eq('id', checklistItemId)
        .maybeSingle();
    if (itemRow == null) return;

    final currentState = itemRow['state']?.toString() ?? 'not_started';

    final rawLinks = await _client
        .from('task_milestone_links')
        .select('progress_percent, tasks(status)')
        .eq('checklist_item_id', checklistItemId);

    var total = 0;
    for (final raw in rawLinks) {
      final row = Map<String, dynamic>.from(raw);
      final taskRaw = row['tasks'];
      final task = taskRaw is Map ? Map<String, dynamic>.from(taskRaw) : null;
      if (task?['status']?.toString() == 'Выполнено') {
        total += _cleanPercent(row['progress_percent']);
      }
    }
    total = total.clamp(0, 100).toInt();

    final nextState = currentState == 'blocked'
        ? 'blocked'
        : total >= 100
            ? 'done'
            : total > 0
                ? 'in_progress'
                : 'not_started';

    await _client.from('milestone_checklist_items').update({
      'state': nextState,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', checklistItemId);
  }
}
