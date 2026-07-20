import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/task_item_data.dart';

class TaskMilestoneLinkData {
  final String milestoneId;
  final String checklistItemId;

  const TaskMilestoneLinkData({
    required this.milestoneId,
    required this.checklistItemId,
  });
}

class TaskMilestoneLinkRepository {
  TaskMilestoneLinkRepository._();

  static final _client = Supabase.instance.client;

  static Future<TaskMilestoneLinkData?> fetchLink(String taskId) async {
    final row = await _client
        .from('task_milestone_links')
        .select('milestone_id, checklist_item_id')
        .eq('task_id', taskId)
        .maybeSingle();

    if (row == null) return null;
    final milestoneId = row['milestone_id']?.toString().trim() ?? '';
    final checklistItemId = row['checklist_item_id']?.toString().trim() ?? '';
    if (milestoneId.isEmpty || checklistItemId.isEmpty) return null;

    return TaskMilestoneLinkData(
      milestoneId: milestoneId,
      checklistItemId: checklistItemId,
    );
  }

  static Future<void> saveLink(TaskItemData task) async {
    final taskId = task.id?.trim() ?? '';
    if (taskId.isEmpty) return;

    final milestoneId = task.milestoneId;
    final checklistItemId = task.checklistItemId;

    // null means that the link was not loaded and must stay untouched.
    if (milestoneId == null && checklistItemId == null) return;

    final cleanMilestoneId = milestoneId?.trim() ?? '';
    final cleanChecklistItemId = checklistItemId?.trim() ?? '';
    if (cleanMilestoneId.isEmpty || cleanChecklistItemId.isEmpty) {
      await _client.from('task_milestone_links').delete().eq('task_id', taskId);
      return;
    }

    await _client.from('task_milestone_links').upsert({
      'task_id': taskId,
      'milestone_id': cleanMilestoneId,
      'checklist_item_id': cleanChecklistItemId,
    }, onConflict: 'task_id');
  }
}
