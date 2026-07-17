import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/milestones/data/milestone_repository.dart';
import '../models/task_act_context.dart';
import '../models/task_item_data.dart';

abstract final class ActContextRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<Map<String, TaskActContext>> fetchForTasks(
    List<TaskItemData> tasks,
  ) async {
    final taskIds = tasks
        .map((task) => task.id?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (taskIds.isEmpty) return const <String, TaskActContext>{};

    final rawLinks = await _client
        .from('task_milestone_links')
        .select('task_id, milestone_id, checklist_item_id')
        .inFilter('task_id', taskIds);

    if (rawLinks.isEmpty) return const <String, TaskActContext>{};

    final milestones = await MilestoneRepository.fetchMilestones(
      includePast: true,
    );
    final milestonesById = {
      for (final milestone in milestones) milestone.id: milestone,
    };

    final result = <String, TaskActContext>{};
    for (final raw in rawLinks) {
      final row = Map<String, dynamic>.from(raw);
      final taskId = row['task_id']?.toString().trim() ?? '';
      final milestoneId = row['milestone_id']?.toString().trim() ?? '';
      final checklistItemId =
          row['checklist_item_id']?.toString().trim() ?? '';
      if (taskId.isEmpty || milestoneId.isEmpty || checklistItemId.isEmpty) {
        continue;
      }

      final milestone = milestonesById[milestoneId];
      if (milestone == null) continue;

      final itemById = {
        for (final item in milestone.items) item.id: item,
      };
      final item = itemById[checklistItemId];
      if (item == null) continue;

      result[taskId] = TaskActContext(
        milestoneTitle: milestone.title,
        milestoneLocation: milestone.location,
        milestoneProgressPercent: milestone.progressPercent,
        checklistTitle: item.title,
        checklistProgressPercent: (item.completionFraction * 100).round(),
        checklistStateTitle: item.stateTitle,
        checklistIsCritical: item.isCritical,
      );
    }

    return Map<String, TaskActContext>.unmodifiable(result);
  }
}
