import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/data/user_repository.dart';
import '../features/developer/data/developer_policy_repository.dart';
import '../models/task_item_data.dart';
import 'app_data_sync.dart';
import 'task_photo_browser_service.dart';
import 'task_photo_models.dart';
import 'task_photo_repository.dart';

export 'task_photo_models.dart';

class TaskAssigneeData {
  final String employeeId;
  final String employeeName;
  final String position;

  const TaskAssigneeData({
    required this.employeeId,
    required this.employeeName,
    required this.position,
  });

  factory TaskAssigneeData.fromSupabase(Map<String, dynamic> json) {
    final employeeRaw = json['employees'];
    final employee = employeeRaw is Map<String, dynamic>
        ? employeeRaw
        : <String, dynamic>{};

    return TaskAssigneeData(
      employeeId: json['employee_id']?.toString() ?? '',
      employeeName: employee['fio']?.toString() ?? 'Сотрудник',
      position: employee['position']?.toString() ?? '',
    );
  }
}

class TaskMilestoneLinkData {
  final String milestoneId;
  final String checklistItemId;

  const TaskMilestoneLinkData({
    required this.milestoneId,
    required this.checklistItemId,
  });
}

class TaskRepository {
  static final _client = Supabase.instance.client;
  static const taskPhotosBucket = TaskPhotoRepository.bucketName;
  static const Duration _tasksCacheTtl = Duration(seconds: 15);

  static final Map<String, _TaskListCacheEntry> _tasksCache = {};

  static String _dateKey(DateTime date) {
    final cleanDate = DateTime(date.year, date.month, date.day);
    final month = cleanDate.month.toString().padLeft(2, '0');
    final day = cleanDate.day.toString().padLeft(2, '0');
    return '${cleanDate.year}-$month-$day';
  }

  static String? cleanObjectName(String? objectName) {
    final clean = objectName?.trim();
    if (clean == null || clean.isEmpty) return null;
    return clean;
  }

  static void clearTaskListCache() {
    _tasksCache.clear();
  }

  static Future<TaskMilestoneLinkData?> fetchTaskMilestoneLink(
    String taskId,
  ) async {
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

  static Future<void> saveTaskMilestoneLink(TaskItemData task) async {
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

  static void _notifyTasksChanged(TaskItemData task) {
    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.tasks},
      context: <String, dynamic>{
        'table': 'tasks',
        'task_date': _dateKey(task.date),
        'object_name': task.objectName,
      },
    );
  }

  static String _tasksCacheKey({
    required DateTime date,
    required String? objectName,
  }) {
    final objectPart = cleanObjectName(objectName) ?? '__all__';
    return '${_dateKey(date)}::$objectPart';
  }

  static bool _isTasksCacheFresh(_TaskListCacheEntry entry) {
    return DateTime.now().difference(entry.createdAt) < _tasksCacheTtl;
  }

  static List<TaskItemData> _copyTasks(List<TaskItemData> tasks) {
    return List<TaskItemData>.from(tasks);
  }

  static String extensionFromFileName(String name) {
    return TaskPhotoBrowserService.extensionFromFileName(name);
  }

  static Uint8List bytesFromReaderResult(Object? result) {
    return TaskPhotoBrowserService.bytesFromReaderResult(result);
  }

  static String safePhotoStoragePath({
    required String taskId,
    required String photoStage,
    required TaskPhotoFile photo,
    required int index,
  }) {
    return TaskPhotoRepository.safeStoragePath(
      taskId: taskId,
      photoStage: photoStage,
      photo: photo,
      index: index,
    );
  }

  static Future<List<TaskPhotoFile>> pickPhotoFiles() {
    return TaskPhotoBrowserService.pickPhotoFiles();
  }

  static Future<List<TaskItemData>> fetchTasksForDate(
    DateTime date, {
    String? objectName,
    bool forceRefresh = false,
  }) async {
    final cleanObject = cleanObjectName(objectName);
    final cacheKey = _tasksCacheKey(date: date, objectName: cleanObject);
    final cached = _tasksCache[cacheKey];

    if (!forceRefresh && cached != null && _isTasksCacheFresh(cached)) {
      return _copyTasks(cached.tasks);
    }

    final rows = cleanObject == null
        ? await _client
              .from('tasks')
              .select(
                'id, task_date, object_name, axes, work, status, not_done_comment',
              )
              .eq('task_date', _dateKey(date))
              .eq('is_draft', false)
              .order('created_at', ascending: true)
        : await _client
              .from('tasks')
              .select(
                'id, task_date, object_name, axes, work, status, not_done_comment',
              )
              .eq('task_date', _dateKey(date))
              .eq('is_draft', false)
              .eq('object_name', cleanObject)
              .order('created_at', ascending: true);

    final tasks = rows
        .map<TaskItemData>((row) => TaskItemData.fromSupabase(row))
        .toList();

    _tasksCache[cacheKey] = _TaskListCacheEntry(
      tasks: _copyTasks(tasks),
      createdAt: DateTime.now(),
    );

    return _copyTasks(tasks);
  }

  static Stream<List<TaskItemData>> watchTasksForDate(
    DateTime date, {
    String? objectName,
  }) {
    final cleanObject = cleanObjectName(objectName);

    return _client
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('task_date', _dateKey(date))
        .order('created_at', ascending: true)
        .map((rows) {
          final visibleRows = rows
              .where((row) => row['is_draft'] != true)
              .toList();
          final filteredRows = cleanObject == null
              ? visibleRows
              : visibleRows.where((row) {
                  final rowObject = row['object_name']?.toString().trim();
                  return rowObject == cleanObject;
                }).toList();

          return filteredRows
              .map<TaskItemData>((row) => TaskItemData.fromSupabase(row))
              .toList();
        });
  }

  static Future<TaskItemData> addTask(
    TaskItemData task, {
    required String objectName,
  }) async {
    final actorName = await UserRepository.currentActorName();
    final policy = await DeveloperPolicyRepository.ensurePolicy(objectName);
    final row = await _client
        .from('tasks')
        .insert({
          'task_date': _dateKey(task.date),
          'object_name': objectName,
          'axes': task.axes,
          'work': task.work,
          'status': task.status,
          'not_done_comment': task.notDoneComment,
          'created_by': actorName,
          'created_by_user_id': _client.auth.currentUser?.id,
          'is_draft': true,
          'photo_requirements_enforced': policy.requireBeforePhoto,
        })
        .select(
          'id, task_date, object_name, axes, work, status, not_done_comment',
        )
        .single();

    return TaskItemData.fromSupabase(row);
  }

  static Future<TaskItemData> addTaskWithDetails(
    TaskItemData task, {
    required String objectName,
    required List<String> assigneeIds,
    required List<TaskPhotoFile> photos,
  }) async {
    final policy = await DeveloperPolicyRepository.ensurePolicy(objectName);
    if (policy.requireBeforePhoto && photos.length < policy.minBeforePhotos) {
      throw Exception('Добавьте фото «До»: минимум ${policy.minBeforePhotos}');
    }

    final createdTask = await addTask(task, objectName: objectName);
    final taskId = createdTask.id;
    if (taskId == null || taskId.isEmpty) return createdTask;

    try {
      await saveTaskAssignees(taskId: taskId, assigneeIds: assigneeIds);
      await uploadPhotosForTask(
        taskId: taskId,
        photos: photos,
        photoStage: 'before',
      );

      final createdWithLink = task.copyWith(id: taskId);
      await saveTaskMilestoneLink(createdWithLink);

      final finalized = await _client
          .from('tasks')
          .update({
            'is_draft': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', taskId)
          .select(
            'id, task_date, object_name, axes, work, status, not_done_comment',
          )
          .single();

      clearTaskListCache();
      final result = TaskItemData.fromSupabase(finalized).copyWith(
        milestoneId: task.milestoneId,
        checklistItemId: task.checklistItemId,
      );
      _notifyTasksChanged(result);
      return result;
    } catch (_) {
      try {
        final draftPhotos = await fetchTaskPhotos(taskId);
        await TaskPhotoRepository.removeStoragePaths(
          draftPhotos.map((photo) => photo.storagePath),
        );
      } catch (_) {
        // Удаление черновика продолжится даже при недоступности Storage.
      }
      try {
        await _client.from('tasks').delete().eq('id', taskId);
      } catch (_) {
        // Черновик скрыт из рабочих списков и может быть удалён служебно.
      }
      rethrow;
    }
  }

  static Future<void> updateTask(TaskItemData task) async {
    if (task.id == null) return;

    await _client
        .from('tasks')
        .update({
          'task_date': _dateKey(task.date),
          'object_name': task.objectName,
          'axes': task.axes,
          'work': task.work,
          'status': task.status,
          'not_done_comment': task.notDoneComment,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', task.id!);

    await saveTaskMilestoneLink(task);
    clearTaskListCache();
    _notifyTasksChanged(task);
  }

  static Future<void> deleteTask(TaskItemData task) async {
    if (task.id == null) return;

    await _client.from('tasks').delete().eq('id', task.id!);
    clearTaskListCache();
    _notifyTasksChanged(task);
  }

  static Future<List<TaskAssigneeData>> fetchTaskAssignees(
    String taskId,
  ) async {
    final rows = await _client
        .from('task_assignees')
        .select('employee_id, employees(fio, position)')
        .eq('task_id', taskId)
        .order('created_at', ascending: true);

    return rows
        .map<TaskAssigneeData>((row) => TaskAssigneeData.fromSupabase(row))
        .toList();
  }

  static Future<List<String>> fetchTaskAssigneeIds(String taskId) async {
    final rows = await _client
        .from('task_assignees')
        .select('employee_id')
        .eq('task_id', taskId);

    return rows
        .map<String>((row) => row['employee_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  }

  static Set<String> cleanAssigneeIdSet(Iterable<String> assigneeIds) {
    return assigneeIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  static bool sameAssigneeIds(
    Iterable<String> firstIds,
    Iterable<String> secondIds,
  ) {
    final first = cleanAssigneeIdSet(firstIds);
    final second = cleanAssigneeIdSet(secondIds);
    if (first.length != second.length) return false;
    return first.every(second.contains);
  }

  static Future<void> saveTaskAssignees({
    required String taskId,
    required List<String> assigneeIds,
  }) async {
    await _client.from('task_assignees').delete().eq('task_id', taskId);

    final cleanIds = cleanAssigneeIdSet(assigneeIds);
    if (cleanIds.isEmpty) return;

    final rows = cleanIds
        .map((employeeId) => {
              'task_id': taskId,
              'employee_id': employeeId,
            })
        .toList();
    await _client.from('task_assignees').insert(rows);
  }

  static Future<void> saveTaskAssigneesIfChanged({
    required String taskId,
    required Iterable<String> previousAssigneeIds,
    required Iterable<String> nextAssigneeIds,
  }) async {
    if (sameAssigneeIds(previousAssigneeIds, nextAssigneeIds)) return;

    await saveTaskAssignees(
      taskId: taskId,
      assigneeIds: cleanAssigneeIdSet(nextAssigneeIds).toList(),
    );
  }

  static Future<List<TaskPhotoData>> fetchTaskPhotos(String taskId) {
    return TaskPhotoRepository.fetchPhotos(taskId);
  }

  static Future<List<TaskPhotoData>> uploadPhotosForTask({
    required String taskId,
    required List<TaskPhotoFile> photos,
    required String photoStage,
  }) {
    return TaskPhotoRepository.uploadPhotos(
      taskId: taskId,
      photos: photos,
      photoStage: photoStage,
    );
  }

  static Future<void> deleteTaskPhoto(TaskPhotoData photo) {
    return TaskPhotoRepository.deletePhoto(photo);
  }

  static Future<String> createTaskPhotoSignedUrl(TaskPhotoData photo) {
    return TaskPhotoRepository.createSignedUrl(photo);
  }

  static Future<void> openTaskPhoto(TaskPhotoData photo) async {
    final url = await createTaskPhotoSignedUrl(photo);
    TaskPhotoBrowserService.openUrl(url);
  }
}

class _TaskListCacheEntry {
  final List<TaskItemData> tasks;
  final DateTime createdAt;

  const _TaskListCacheEntry({
    required this.tasks,
    required this.createdAt,
  });
}
