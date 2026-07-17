import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/milestone_models.dart';

abstract final class MilestoneRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  static String? _cleanObject(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  static const concreteChecklist = <MilestoneChecklistDraft>[
    MilestoneChecklistDraft(
      title: 'Рабочая документация и разрешения готовы',
      weight: 10,
      isCritical: true,
    ),
    MilestoneChecklistDraft(
      title: 'Армирование завершено',
      weight: 20,
      isCritical: true,
    ),
    MilestoneChecklistDraft(
      title: 'Опалубка установлена',
      weight: 20,
      isCritical: true,
    ),
    MilestoneChecklistDraft(
      title: 'Закладные и отверстия проверены',
      weight: 10,
      isCritical: false,
    ),
    MilestoneChecklistDraft(
      title: 'Геодезическая проверка выполнена',
      weight: 10,
      isCritical: true,
    ),
    MilestoneChecklistDraft(
      title: 'Приёмка технадзором пройдена',
      weight: 15,
      isCritical: true,
    ),
    MilestoneChecklistDraft(
      title: 'Материалы и техника готовы',
      weight: 10,
      isCritical: true,
    ),
    MilestoneChecklistDraft(
      title: 'Бригада назначена',
      weight: 5,
      isCritical: false,
    ),
  ];

  static const generalChecklist = <MilestoneChecklistDraft>[
    MilestoneChecklistDraft(
      title: 'Рабочая документация проверена',
      weight: 20,
      isCritical: true,
    ),
    MilestoneChecklistDraft(
      title: 'Материалы на объекте',
      weight: 25,
      isCritical: true,
    ),
    MilestoneChecklistDraft(
      title: 'Предшествующие работы завершены',
      weight: 25,
      isCritical: true,
    ),
    MilestoneChecklistDraft(
      title: 'Люди и техника назначены',
      weight: 15,
      isCritical: false,
    ),
    MilestoneChecklistDraft(
      title: 'Контроль и приёмка организованы',
      weight: 15,
      isCritical: true,
    ),
  ];

  static Future<List<ProjectMilestone>> fetchMilestones({
    String? objectName,
    DateTime? fromDate,
    bool includePast = true,
  }) async {
    final cleanObject = _cleanObject(objectName);
    var query = _client
        .from('project_milestones')
        .select('id, object_name, title, location, target_date, status, notes');

    if (cleanObject != null) {
      query = query.eq('object_name', cleanObject);
    }
    if (!includePast) {
      query = query.gte('target_date', _dateKey(fromDate ?? DateTime.now()));
    }

    final milestoneRows = await query.order('target_date', ascending: true);
    if (milestoneRows.isEmpty) return const <ProjectMilestone>[];

    final milestoneIds = milestoneRows
        .map<String>((row) => row['id'].toString())
        .toList();

    final results = await Future.wait<dynamic>([
      _client
          .from('milestone_checklist_items')
          .select(
            'id, milestone_id, title, weight, state, is_critical, sort_order',
          )
          .inFilter('milestone_id', milestoneIds)
          .order('sort_order', ascending: true),
      _client
          .from('task_milestone_links')
          .select(
            'task_id, milestone_id, checklist_item_id, tasks(id, work, axes, status, task_date)',
          )
          .inFilter('milestone_id', milestoneIds),
    ]);

    final tasksByItem = <String, List<MilestoneTaskData>>{};
    for (final raw in results[1] as List<dynamic>) {
      final row = Map<String, dynamic>.from(raw as Map);
      final itemId = row['checklist_item_id']?.toString() ?? '';
      final taskRaw = row['tasks'];
      if (itemId.isEmpty || taskRaw is! Map) continue;
      final task = Map<String, dynamic>.from(taskRaw);
      tasksByItem.putIfAbsent(itemId, () => <MilestoneTaskData>[]).add(
            MilestoneTaskData(
              taskId: task['id']?.toString() ?? row['task_id'].toString(),
              work: task['work']?.toString() ?? '',
              axes: task['axes']?.toString() ?? '',
              status: task['status']?.toString() ?? 'Запланировано',
              date: DateTime.tryParse(task['task_date']?.toString() ?? '') ??
                  DateTime.now(),
            ),
          );
    }

    final itemsByMilestone = <String, List<MilestoneChecklistItem>>{};
    for (final raw in results[0] as List<dynamic>) {
      final row = Map<String, dynamic>.from(raw as Map);
      final milestoneId = row['milestone_id']?.toString() ?? '';
      final itemId = row['id']?.toString() ?? '';
      if (milestoneId.isEmpty || itemId.isEmpty) continue;
      itemsByMilestone
          .putIfAbsent(milestoneId, () => <MilestoneChecklistItem>[])
          .add(
            MilestoneChecklistItem(
              id: itemId,
              milestoneId: milestoneId,
              title: row['title']?.toString() ?? '',
              weight: (row['weight'] as num?)?.toInt() ?? 10,
              state: row['state']?.toString() ?? 'not_started',
              isCritical: row['is_critical'] == true,
              sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
              tasks: List<MilestoneTaskData>.unmodifiable(
                tasksByItem[itemId] ?? const <MilestoneTaskData>[],
              ),
            ),
          );
    }

    return milestoneRows.map<ProjectMilestone>((raw) {
      final row = Map<String, dynamic>.from(raw);
      final id = row['id']?.toString() ?? '';
      return ProjectMilestone(
        id: id,
        objectName: row['object_name']?.toString() ?? '',
        title: row['title']?.toString() ?? '',
        location: row['location']?.toString() ?? '',
        targetDate:
            DateTime.tryParse(row['target_date']?.toString() ?? '') ??
                DateTime.now(),
        status: row['status']?.toString() ?? 'planned',
        notes: row['notes']?.toString() ?? '',
        items: List<MilestoneChecklistItem>.unmodifiable(
          itemsByMilestone[id] ?? const <MilestoneChecklistItem>[],
        ),
      );
    }).toList();
  }

  static Future<ProjectMilestone?> fetchNearest({String? objectName}) async {
    final rows = await fetchMilestones(
      objectName: objectName,
      fromDate: DateTime.now(),
      includePast: false,
    );
    for (final milestone in rows) {
      if (!milestone.isCompleted && milestone.status != 'postponed') {
        return milestone;
      }
    }
    return rows.isEmpty ? null : rows.first;
  }

  static Future<String> createMilestone({
    required String objectName,
    required String title,
    required String location,
    required DateTime targetDate,
    required String notes,
    required List<MilestoneChecklistDraft> checklist,
  }) async {
    final row = await _client
        .from('project_milestones')
        .insert({
          'object_name': objectName.trim(),
          'title': title.trim(),
          'location': location.trim(),
          'target_date': _dateKey(targetDate),
          'status': 'planned',
          'notes': notes.trim(),
        })
        .select('id')
        .single();
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) throw Exception('Не удалось создать ключевой этап');

    if (checklist.isNotEmpty) {
      await _client.from('milestone_checklist_items').insert(
            List<Map<String, dynamic>>.generate(checklist.length, (index) {
              final item = checklist[index];
              return {
                'milestone_id': id,
                'title': item.title,
                'weight': item.weight,
                'is_critical': item.isCritical,
                'sort_order': index,
              };
            }),
          );
    }
    return id;
  }

  static Future<void> updateMilestoneStatus({
    required String milestoneId,
    required String status,
  }) async {
    await _client.from('project_milestones').update({
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', milestoneId);
  }

  static Future<void> updateChecklistState({
    required String itemId,
    required String state,
  }) async {
    await _client.from('milestone_checklist_items').update({
      'state': state,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', itemId);
  }

  static Future<void> addChecklistItem({
    required String milestoneId,
    required String title,
    required int weight,
    required bool isCritical,
    required int sortOrder,
  }) async {
    await _client.from('milestone_checklist_items').insert({
      'milestone_id': milestoneId,
      'title': title.trim(),
      'weight': weight,
      'is_critical': isCritical,
      'sort_order': sortOrder,
    });
  }

  static Future<void> updateChecklistItem({
    required String itemId,
    required String title,
    required int weight,
    required bool isCritical,
  }) async {
    await _client.from('milestone_checklist_items').update({
      'title': title.trim(),
      'weight': weight,
      'is_critical': isCritical,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', itemId);
  }

  static Future<void> deleteChecklistItem(String itemId) async {
    await _client
        .from('milestone_checklist_items')
        .delete()
        .eq('id', itemId);
  }

  static Future<void> linkTask({
    required String taskId,
    required String milestoneId,
    required String checklistItemId,
  }) async {
    await _client.from('task_milestone_links').upsert(
      {
        'task_id': taskId,
        'milestone_id': milestoneId,
        'checklist_item_id': checklistItemId,
      },
      onConflict: 'task_id',
    );
  }

  static Future<void> unlinkTask(String taskId) async {
    await _client.from('task_milestone_links').delete().eq('task_id', taskId);
  }

  static Future<void> deleteMilestone(String milestoneId) async {
    await _client.from('project_milestones').delete().eq('id', milestoneId);
  }
}
