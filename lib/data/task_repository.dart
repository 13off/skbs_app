import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/data/user_repository.dart';
import '../features/developer/data/developer_policy_repository.dart';
import '../models/responsibility_actor.dart';
import '../models/task_item_data.dart';
import 'app_data_sync.dart';
import 'offline_sync_service.dart';
import 'task_assignee_repository.dart';
import 'task_milestone_link_repository.dart';
import 'task_photo_browser_service.dart';
import 'task_photo_models.dart';
import 'task_photo_repository.dart';

export 'task_assignee_repository.dart' show TaskAssigneeData;
export 'task_milestone_link_repository.dart' show TaskMilestoneLinkData;
export 'task_photo_models.dart';

class TaskRepository {
  static final _client = Supabase.instance.client;
  static const taskPhotosBucket = TaskPhotoRepository.bucketName;
  static const Duration _tasksCacheTtl = Duration(seconds: 15);

  static final Map<String, _TaskListCacheEntry> _tasksCache = {};
  static final Map<String, Future<List<TaskItemData>>> _taskRequests = {};
  static int _cacheGeneration = 0;

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
    _cacheGeneration++;
    _tasksCache.clear();
    _taskRequests.clear();
  }

  static Future<TaskMilestoneLinkData?> fetchTaskMilestoneLink(
    String taskId,
  ) async {
    final key = 'task_link::${taskId.trim()}';
    try {
      final link = await TaskMilestoneLinkRepository.fetchLink(taskId);
      await OfflineSyncService.saveSnapshot(
        key,
        link == null
            ? null
            : <String, dynamic>{
                'milestone_id': link.milestoneId,
                'checklist_item_id': link.checklistItemId,
              },
      );
      await OfflineSyncService.markSynced();
      return link;
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      final cached = await OfflineSyncService.readSnapshot(key);
      if (cached is! Map) return null;
      final row = Map<String, dynamic>.from(cached);
      final milestoneId = row['milestone_id']?.toString().trim() ?? '';
      final checklistItemId = row['checklist_item_id']?.toString().trim() ?? '';
      if (milestoneId.isEmpty || checklistItemId.isEmpty) return null;
      return TaskMilestoneLinkData(
        milestoneId: milestoneId,
        checklistItemId: checklistItemId,
      );
    }
  }

  static Future<void> saveTaskMilestoneLink(TaskItemData task) async {
    try {
      await TaskMilestoneLinkRepository.saveLink(task);
      await OfflineSyncService.markSynced();
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      final taskId = task.id?.trim() ?? '';
      if (taskId.isEmpty) return;
      await OfflineSyncService.enqueue(
        kind: 'task.link',
        dedupeKey: taskId,
        payload: <String, dynamic>{
          'id': taskId,
          'milestone_id': task.milestoneId,
          'checklist_item_id': task.checklistItemId,
        },
      );
    }
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

  static String _tasksSnapshotKey(String cacheKey) => 'tasks::$cacheKey';

  static String _draftSnapshotKey(String? objectName) {
    final objectPart = cleanObjectName(objectName) ?? '__all__';
    return 'task_drafts::$objectPart';
  }

  static bool _isTasksCacheFresh(_TaskListCacheEntry entry) {
    return DateTime.now().difference(entry.createdAt) < _tasksCacheTtl;
  }

  static List<TaskItemData> _copyTasks(List<TaskItemData> tasks) {
    return List<TaskItemData>.from(tasks);
  }

  static Map<String, dynamic>? _actorToSnapshot(ResponsibilityActor? actor) {
    if (actor == null) return null;
    return <String, dynamic>{
      'user_id': actor.userId,
      'full_name': actor.fullName,
      'avatar_path': actor.avatarPath,
      'acted_at': actor.actedAt?.toUtc().toIso8601String(),
    };
  }

  static ResponsibilityActor? _actorFromSnapshot(dynamic raw) {
    if (raw is! Map) return null;
    final row = Map<String, dynamic>.from(raw);
    final fullName = row['full_name']?.toString().trim() ?? '';
    if (fullName.isEmpty) return null;
    return ResponsibilityActor(
      userId: ResponsibilityActor.cleanText(row['user_id']),
      fullName: fullName,
      avatarPath: ResponsibilityActor.cleanText(row['avatar_path']),
      actedAt: DateTime.tryParse(row['acted_at']?.toString() ?? '')?.toLocal(),
    );
  }

  static Map<String, dynamic> _taskToSnapshot(TaskItemData task) {
    return <String, dynamic>{
      ...task.toJson(),
      'creator': _actorToSnapshot(task.creator),
      'last_editor': _actorToSnapshot(task.lastEditor),
    };
  }

  static TaskItemData _taskFromSnapshot(Map<String, dynamic> row) {
    final task = TaskItemData.fromJson(row);
    return task.copyWith(
      creator: _actorFromSnapshot(row['creator']),
      lastEditor: _actorFromSnapshot(row['last_editor']),
    );
  }

  static Future<void> _saveTaskSnapshot(
    String cacheKey,
    List<TaskItemData> tasks,
  ) async {
    await OfflineSyncService.saveSnapshot(
      _tasksSnapshotKey(cacheKey),
      tasks.map(_taskToSnapshot).toList(growable: false),
    );
  }

  static Future<List<TaskItemData>> _readTaskSnapshot(String cacheKey) async {
    final cached = await OfflineSyncService.readSnapshot(
      _tasksSnapshotKey(cacheKey),
    );
    if (cached is! List) return <TaskItemData>[];
    return cached
        .whereType<Map>()
        .map((row) => _taskFromSnapshot(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  static Future<void> _saveDraftSnapshot(
    String? objectName,
    List<TaskItemData> tasks,
  ) async {
    await OfflineSyncService.saveSnapshot(
      _draftSnapshotKey(objectName),
      tasks.map(_taskToSnapshot).toList(growable: false),
    );
  }

  static Future<List<TaskItemData>> _readDraftSnapshot(
    String? objectName,
  ) async {
    final cached = await OfflineSyncService.readSnapshot(
      _draftSnapshotKey(objectName),
    );
    if (cached is! List) return <TaskItemData>[];
    return cached
        .whereType<Map>()
        .map((row) => _taskFromSnapshot(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  static Future<List<TaskItemData>> _mergePendingTaskOverlay(
    String cacheKey,
    List<TaskItemData> serverTasks,
  ) async {
    if (OfflineSyncService.pendingCount == 0) return serverTasks;

    final localTasks = await _readTaskSnapshot(cacheKey);
    final mutationIds = await OfflineSyncService.pendingTaskMutationIds();
    final deleteIds = await OfflineSyncService.pendingTaskDeleteIds();
    if (mutationIds.isEmpty && deleteIds.isEmpty) return serverTasks;

    final byId = <String, TaskItemData>{};
    final withoutId = <TaskItemData>[];
    for (final task in serverTasks) {
      final id = task.id?.trim() ?? '';
      if (id.isEmpty) {
        withoutId.add(task);
      } else if (!deleteIds.contains(id)) {
        byId[id] = task;
      }
    }
    for (final task in localTasks) {
      final id = task.id?.trim() ?? '';
      if (id.isNotEmpty && mutationIds.contains(id) && !deleteIds.contains(id)) {
        byId[id] = task;
      }
    }
    return <TaskItemData>[...withoutId, ...byId.values];
  }

  static Future<void> _upsertTaskSnapshot(TaskItemData task) async {
    final cacheKey = _tasksCacheKey(date: task.date, objectName: task.objectName);
    final current = await _readTaskSnapshot(cacheKey);
    final id = task.id?.trim() ?? '';
    final next = <TaskItemData>[
      for (final item in current)
        if (id.isEmpty || item.id != id) item,
      task,
    ];
    await _saveTaskSnapshot(cacheKey, next);
  }

  static Future<void> _removeTaskSnapshot(TaskItemData task) async {
    final id = task.id?.trim() ?? '';
    if (id.isEmpty) return;
    final cacheKey = _tasksCacheKey(date: task.date, objectName: task.objectName);
    final current = await _readTaskSnapshot(cacheKey);
    await _saveTaskSnapshot(
      cacheKey,
      current.where((item) => item.id != id).toList(growable: false),
    );
  }

  static Future<void> _upsertDraftSnapshot(
    TaskItemData task,
    String? objectName,
  ) async {
    final current = await _readDraftSnapshot(objectName);
    final id = task.id?.trim() ?? '';
    await _saveDraftSnapshot(
      objectName,
      <TaskItemData>[
        for (final item in current)
          if (id.isEmpty || item.id != id) item,
        task,
      ],
    );
  }

  static Future<String> _currentActorNameSafe() async {
    try {
      return await UserRepository.currentActorName();
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      final name = UserRepository.cachedProfile?.fullName.trim() ?? '';
      if (name.isNotEmpty) return name;
      final email = UserRepository.currentUser?.email?.trim() ?? '';
      return email.isEmpty ? 'Пользователь' : email;
    }
  }

  static Future<dynamic> _policyForObject(String objectName) async {
    try {
      return await DeveloperPolicyRepository.ensurePolicy(objectName);
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      return DeveloperPolicyRepository.policyForObjectSync(objectName);
    }
  }

  static Future<TaskItemData> _queueTaskCreate(
    TaskItemData task, {
    required String objectName,
    required List<String> assigneeIds,
    required List<TaskPhotoFile> photos,
    required bool isDraft,
    String? preferredId,
  }) async {
    final cleanPreferredId = preferredId?.trim() ?? '';
    final taskId = cleanPreferredId.isNotEmpty
        ? cleanPreferredId
        : OfflineSyncService.createLocalId();
    final policy = await _policyForObject(objectName);
    final actorName = await _currentActorNameSafe();
    final localTask = task.copyWith(
      id: taskId,
      objectName: objectName,
      status: isDraft ? 'Запланировано' : task.status,
    );
    final row = <String, dynamic>{
      'id': taskId,
      'task_date': _dateKey(localTask.date),
      'object_name': objectName,
      'axes': localTask.axes,
      'work': localTask.work,
      'status': localTask.status,
      'not_done_comment': localTask.notDoneComment,
      'created_by': actorName,
      'created_by_user_id': _client.auth.currentUser?.id,
      'is_draft': isDraft,
      'photo_requirements_enforced': policy.requireBeforePhoto,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    await OfflineSyncService.enqueue(
      kind: 'task.create',
      dedupeKey: taskId,
      payload: <String, dynamic>{
        'id': taskId,
        'row': row,
        'assignee_ids': assigneeIds,
        'milestone_id': localTask.milestoneId,
        'checklist_item_id': localTask.checklistItemId,
        'photos': photos
            .map(
              (photo) => OfflineSyncService.serializePhoto(
                originalName: photo.originalName,
                contentType: photo.contentType,
                extension: photo.extension,
                bytes: photo.bytes,
              ),
            )
            .toList(growable: false),
      },
    );

    if (isDraft) {
      await _upsertDraftSnapshot(localTask, objectName);
    } else {
      await _upsertTaskSnapshot(localTask);
    }
    clearTaskListCache();
    _notifyTasksChanged(localTask);
    return localTask;
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
    final cacheKey = _tasksCacheKey(date: date, objectName: objectName);
    final running = _taskRequests[cacheKey];
    if (running != null) return _copyTasks(await running);

    final request = _fetchTasksForDate(
      date,
      objectName: objectName,
      forceRefresh: forceRefresh,
    );
    _taskRequests[cacheKey] = request;

    try {
      return _copyTasks(await request);
    } finally {
      if (identical(_taskRequests[cacheKey], request)) {
        _taskRequests.remove(cacheKey);
      }
    }
  }

  static Future<List<TaskItemData>> _fetchTasksForDate(
    DateTime date, {
    String? objectName,
    bool forceRefresh = false,
  }) async {
    final generation = _cacheGeneration;
    final cleanObject = cleanObjectName(objectName);
    final cacheKey = _tasksCacheKey(date: date, objectName: cleanObject);
    final cached = _tasksCache[cacheKey];

    if (!forceRefresh && cached != null && _isTasksCacheFresh(cached)) {
      return _copyTasks(cached.tasks);
    }

    try {
      final params = <String, dynamic>{
        'p_task_date': _dateKey(date),
        'p_object_name': cleanObject,
      };
      final responses = await Future.wait<dynamic>([
        _client.rpc<dynamic>('get_task_rows_fast', params: params),
        _client.rpc<dynamic>('get_task_responsibility_fast', params: params),
      ]);
      final response = responses[0];
      if (response is! List) return <TaskItemData>[];

      final responsibilityByTaskId = <String, Map<String, dynamic>>{};
      final responsibilityResponse = responses[1];
      if (responsibilityResponse is List) {
        for (final raw in responsibilityResponse.whereType<Map>()) {
          final row = Map<String, dynamic>.from(raw);
          final taskId = row['task_id']?.toString();
          if (taskId != null && taskId.isNotEmpty) {
            responsibilityByTaskId[taskId] = row;
          }
        }
      }

      final serverTasks = response
          .whereType<Map>()
          .map<TaskItemData>((raw) {
            final row = Map<String, dynamic>.from(raw);
            final task = TaskItemData.fromSupabase(row);
            final responsibility = responsibilityByTaskId[task.id];
            if (responsibility == null) return task;

            final creator = ResponsibilityActor.fromMap(
              responsibility,
              userIdKey: 'creator_user_id',
              fullNameKey: 'creator_full_name',
              avatarPathKey: 'creator_avatar_path',
              actedAtKey: 'created_at',
            );
            final lastEditorUserId = ResponsibilityActor.cleanText(
              responsibility['last_editor_user_id'],
            );
            final lastEditor = lastEditorUserId == null
                ? null
                : ResponsibilityActor.fromMap(
                    responsibility,
                    userIdKey: 'last_editor_user_id',
                    fullNameKey: 'last_editor_full_name',
                    avatarPathKey: 'last_editor_avatar_path',
                    actedAtKey: 'last_edited_at',
                  );
            return task.copyWith(creator: creator, lastEditor: lastEditor);
          })
          .toList(growable: false);

      final tasks = await _mergePendingTaskOverlay(cacheKey, serverTasks);
      if (generation == _cacheGeneration) {
        _tasksCache[cacheKey] = _TaskListCacheEntry(
          tasks: _copyTasks(tasks),
          createdAt: DateTime.now(),
        );
      }
      await _saveTaskSnapshot(cacheKey, tasks);
      await OfflineSyncService.markSynced();
      return _copyTasks(tasks);
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      final cached = await OfflineSyncService.readSnapshot(
        _tasksSnapshotKey(cacheKey),
      );
      if (cached is! List) rethrow;
      final tasks = cached
          .whereType<Map>()
          .map(
            (row) => _taskFromSnapshot(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
      return _copyTasks(tasks);
    }
  }

  static Future<List<TaskItemData>> fetchOwnDraftTasks({
    String? objectName,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return <TaskItemData>[];

    try {
      var query = _client
          .from('tasks')
          .select(
            'id, task_date, object_name, axes, work, status, not_done_comment',
          )
          .eq('is_draft', true)
          .eq('created_by_user_id', userId);
      final cleanObject = cleanObjectName(objectName);
      if (cleanObject != null) {
        query = query.eq('object_name', cleanObject);
      }

      final response = await query.order('updated_at', ascending: false);
      final serverDrafts = response
          .map<TaskItemData>(
            (row) =>
                TaskItemData.fromSupabase(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
      final localDrafts = await _readDraftSnapshot(objectName);
      final mutationIds = await OfflineSyncService.pendingTaskMutationIds();
      final byId = <String, TaskItemData>{
        for (final task in serverDrafts)
          if (task.id?.trim().isNotEmpty == true) task.id!: task,
      };
      for (final task in localDrafts) {
        final id = task.id?.trim() ?? '';
        if (id.isNotEmpty && mutationIds.contains(id)) byId[id] = task;
      }
      final result = byId.values.toList(growable: false);
      await _saveDraftSnapshot(objectName, result);
      await OfflineSyncService.markSynced();
      return result;
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      return _readDraftSnapshot(objectName);
    }
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
    final actorName = await _currentActorNameSafe();
    final policy = await _policyForObject(objectName);
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

  static Future<TaskItemData> saveTaskDraftWithDetails(
    TaskItemData task, {
    required String objectName,
    required List<String> assigneeIds,
    String? sourceDraftId,
  }) async {
    try {
      final createdTask = await addTask(
        task.copyWith(status: 'Запланировано'),
        objectName: objectName,
      );
      final taskId = createdTask.id;
      if (taskId == null || taskId.isEmpty) return createdTask;

      try {
        await TaskAssigneeRepository.saveAssignees(
          taskId: taskId,
          assigneeIds: assigneeIds,
        );
        final linkedTask = task.copyWith(id: taskId, status: 'Запланировано');
        await TaskMilestoneLinkRepository.saveLink(linkedTask);

        final cleanSourceId = sourceDraftId?.trim() ?? '';
        if (cleanSourceId.isNotEmpty && cleanSourceId != taskId) {
          await deleteTaskDraft(cleanSourceId);
        }

        clearTaskListCache();
        final result = createdTask.copyWith(
          milestoneId: task.milestoneId,
          checklistItemId: task.checklistItemId,
        );
        await _upsertDraftSnapshot(result, objectName);
        await OfflineSyncService.markSynced();
        _notifyTasksChanged(result);
        return result;
      } catch (_) {
        try {
          await _client.from('tasks').delete().eq('id', taskId);
        } catch (_) {
          // Не оставляем повреждённый черновик, если сервер доступен частично.
        }
        rethrow;
      }
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      return _queueTaskCreate(
        task.copyWith(status: 'Запланировано'),
        objectName: objectName,
        assigneeIds: assigneeIds,
        photos: const <TaskPhotoFile>[],
        isDraft: true,
        preferredId: sourceDraftId,
      );
    }
  }

  static Future<void> deleteTaskDraft(String taskId) async {
    final cleanTaskId = taskId.trim();
    if (cleanTaskId.isEmpty) return;

    try {
      await _client
          .from('tasks')
          .delete()
          .eq('id', cleanTaskId)
          .eq('is_draft', true);
      await OfflineSyncService.markSynced();
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      await OfflineSyncService.enqueue(
        kind: 'task.delete',
        dedupeKey: cleanTaskId,
        payload: <String, dynamic>{'id': cleanTaskId},
      );
    }
    clearTaskListCache();
    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.tasks},
      context: <String, dynamic>{
        'table': 'tasks',
        'task_id': cleanTaskId,
        'is_draft': true,
      },
    );
  }

  static Future<TaskItemData> addTaskWithDetails(
    TaskItemData task, {
    required String objectName,
    required List<String> assigneeIds,
    required List<TaskPhotoFile> photos,
  }) async {
    final policy = await _policyForObject(objectName);
    if (policy.requireBeforePhoto && photos.length < policy.minBeforePhotos) {
      throw Exception('Добавьте фото «До»: минимум ${policy.minBeforePhotos}');
    }

    try {
      final createdTask = await addTask(task, objectName: objectName);
      final taskId = createdTask.id;
      if (taskId == null || taskId.isEmpty) return createdTask;

      try {
        await TaskAssigneeRepository.saveAssignees(
          taskId: taskId,
          assigneeIds: assigneeIds,
        );
        await uploadPhotosForTask(
          taskId: taskId,
          photos: photos,
          photoStage: 'before',
        );

        final createdWithLink = task.copyWith(id: taskId);
        await TaskMilestoneLinkRepository.saveLink(createdWithLink);

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
        await _upsertTaskSnapshot(result);
        await OfflineSyncService.markSynced();
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
          // Скрытый серверный черновик можно удалить после восстановления сети.
        }
        rethrow;
      }
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      return _queueTaskCreate(
        task,
        objectName: objectName,
        assigneeIds: assigneeIds,
        photos: photos,
        isDraft: false,
      );
    }
  }

  static Future<List<TaskItemData>> addTaskBatch({
    required String objectName,
    required List<TaskBatchCreateInput> tasks,
  }) async {
    if (tasks.length < 2) {
      throw ArgumentError.value(tasks.length, 'tasks', 'Ожидался пакет задач');
    }

    try {
      final response = await _client.rpc<dynamic>(
        'create_task_batch',
        params: <String, dynamic>{
          'p_object_name': objectName.trim(),
          'p_tasks': tasks.map((task) => task.toJson()).toList(growable: false),
        },
      );
      if (response is! List || response.length != tasks.length) {
        throw Exception('Сервер вернул неполный результат создания задач');
      }

      clearTaskListCache();
      final result = <TaskItemData>[];
      for (var index = 0; index < response.length; index += 1) {
        final row = response[index];
        if (row is! Map) {
          throw Exception('Сервер вернул повреждённый результат создания задач');
        }
        final source = tasks[index].task;
        final created = TaskItemData.fromSupabase(
          Map<String, dynamic>.from(row),
        ).copyWith(
          milestoneId: source.milestoneId,
          checklistItemId: source.checklistItemId,
        );
        result.add(created);
        await _upsertTaskSnapshot(created);
      }
      await OfflineSyncService.markSynced();
      AppDataSync.notifyLocal(
        const <AppDataDomain>{AppDataDomain.tasks},
        context: <String, dynamic>{
          'table': 'tasks',
          'object_name': objectName.trim(),
          'batch_size': result.length,
        },
      );
      return result;
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      final result = <TaskItemData>[];
      for (final input in tasks) {
        result.add(
          await _queueTaskCreate(
            input.task,
            objectName: objectName,
            assigneeIds: input.assigneeIds,
            photos: const <TaskPhotoFile>[],
            isDraft: false,
          ),
        );
      }
      return result;
    }
  }

  static Future<void> updateTask(TaskItemData task) async {
    final taskId = task.id?.trim() ?? '';
    if (taskId.isEmpty) return;

    final values = <String, dynamic>{
      'task_date': _dateKey(task.date),
      'object_name': task.objectName,
      'axes': task.axes,
      'work': task.work,
      'status': task.status,
      'not_done_comment': task.notDoneComment,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await _client.from('tasks').update(values).eq('id', taskId);
      await TaskMilestoneLinkRepository.saveLink(task);
      await OfflineSyncService.markSynced();
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      await OfflineSyncService.enqueue(
        kind: 'task.update',
        dedupeKey: taskId,
        payload: <String, dynamic>{
          'id': taskId,
          'values': values,
          'milestone_id': task.milestoneId,
          'checklist_item_id': task.checklistItemId,
        },
      );
    }

    await _upsertTaskSnapshot(task);
    clearTaskListCache();
    _notifyTasksChanged(task);
  }

  static Future<void> deleteTask(TaskItemData task) async {
    final taskId = task.id?.trim() ?? '';
    if (taskId.isEmpty) return;

    try {
      await _client.from('tasks').delete().eq('id', taskId);
      await OfflineSyncService.markSynced();
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      await OfflineSyncService.enqueue(
        kind: 'task.delete',
        dedupeKey: taskId,
        payload: <String, dynamic>{'id': taskId},
      );
    }

    await _removeTaskSnapshot(task);
    clearTaskListCache();
    _notifyTasksChanged(task);
  }

  static Future<List<TaskAssigneeData>> fetchTaskAssignees(
    String taskId,
  ) async {
    final cleanTaskId = taskId.trim();
    final key = 'task_assignees::$cleanTaskId';
    try {
      final result = await TaskAssigneeRepository.fetchAssignees(cleanTaskId);
      await OfflineSyncService.saveSnapshot(
        key,
        result
            .map(
              (item) => <String, dynamic>{
                'employee_id': item.employeeId,
                'employee_name': item.employeeName,
                'position': item.position,
              },
            )
            .toList(growable: false),
      );
      await OfflineSyncService.markSynced();
      return result;
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      final cached = await OfflineSyncService.readSnapshot(key);
      if (cached is! List) return <TaskAssigneeData>[];
      return cached.whereType<Map>().map((raw) {
        final row = Map<String, dynamic>.from(raw);
        return TaskAssigneeData(
          employeeId: row['employee_id']?.toString() ?? '',
          employeeName: row['employee_name']?.toString() ?? 'Сотрудник',
          position: row['position']?.toString() ?? '',
        );
      }).toList(growable: false);
    }
  }

  static Future<List<String>> fetchTaskAssigneeIds(String taskId) async {
    final cleanTaskId = taskId.trim();
    final key = 'task_assignee_ids::$cleanTaskId';
    try {
      final result = await TaskAssigneeRepository.fetchAssigneeIds(cleanTaskId);
      await OfflineSyncService.saveSnapshot(key, result);
      await OfflineSyncService.markSynced();
      return result;
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      final cached = await OfflineSyncService.readSnapshot(key);
      if (cached is! List) return <String>[];
      return cached
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
    }
  }

  static Set<String> cleanAssigneeIdSet(Iterable<String> assigneeIds) {
    return TaskAssigneeRepository.cleanIdSet(assigneeIds);
  }

  static bool sameAssigneeIds(
    Iterable<String> firstIds,
    Iterable<String> secondIds,
  ) {
    return TaskAssigneeRepository.sameIds(firstIds, secondIds);
  }

  static Future<void> saveTaskAssignees({
    required String taskId,
    required List<String> assigneeIds,
  }) async {
    final cleanTaskId = taskId.trim();
    if (cleanTaskId.isEmpty) return;
    try {
      await TaskAssigneeRepository.saveAssignees(
        taskId: cleanTaskId,
        assigneeIds: assigneeIds,
      );
      await OfflineSyncService.markSynced();
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      await OfflineSyncService.enqueue(
        kind: 'task.assignees',
        dedupeKey: cleanTaskId,
        payload: <String, dynamic>{
          'id': cleanTaskId,
          'assignee_ids': assigneeIds,
        },
      );
    }
    await OfflineSyncService.saveSnapshot(
      'task_assignee_ids::$cleanTaskId',
      assigneeIds,
    );
  }

  static Future<void> saveTaskAssigneesIfChanged({
    required String taskId,
    required Iterable<String> previousAssigneeIds,
    required Iterable<String> nextAssigneeIds,
  }) async {
    if (TaskAssigneeRepository.sameIds(previousAssigneeIds, nextAssigneeIds)) {
      return;
    }
    await saveTaskAssignees(
      taskId: taskId,
      assigneeIds: TaskAssigneeRepository.cleanIdSet(nextAssigneeIds).toList(),
    );
  }

  static Future<List<TaskPhotoData>> fetchTaskPhotos(String taskId) async {
    final cleanTaskId = taskId.trim();
    final key = 'task_photos::$cleanTaskId';
    try {
      final result = await TaskPhotoRepository.fetchPhotos(cleanTaskId);
      await OfflineSyncService.saveSnapshot(
        key,
        result
            .map(
              (photo) => <String, dynamic>{
                'id': photo.id,
                'task_id': photo.taskId,
                'storage_path': photo.storagePath,
                'original_name': photo.originalName,
                'photo_stage': photo.photoStage,
                'created_at': photo.createdAt.toUtc().toIso8601String(),
              },
            )
            .toList(growable: false),
      );
      await OfflineSyncService.markSynced();
      return result;
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      final cached = await OfflineSyncService.readSnapshot(key);
      if (cached is! List) return <TaskPhotoData>[];
      return cached
          .whereType<Map>()
          .map(
            (row) => TaskPhotoData.fromSupabase(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(growable: false);
    }
  }

  static Future<List<TaskPhotoData>> uploadPhotosForTask({
    required String taskId,
    required List<TaskPhotoFile> photos,
    required String photoStage,
  }) async {
    if (photos.isEmpty) return <TaskPhotoData>[];
    try {
      final result = await TaskPhotoRepository.uploadPhotos(
        taskId: taskId,
        photos: photos,
        photoStage: photoStage,
      );
      await OfflineSyncService.markSynced();
      return result;
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      final queued = photos
          .map(
            (photo) => OfflineSyncService.serializePhoto(
              originalName: photo.originalName,
              contentType: photo.contentType,
              extension: photo.extension,
              bytes: photo.bytes,
              photoStage: photoStage,
            ),
          )
          .toList(growable: false);
      await OfflineSyncService.enqueue(
        kind: 'task.photos.add',
        dedupeKey: '${taskId.trim()}::$photoStage',
        payload: <String, dynamic>{
          'id': taskId.trim(),
          'photo_stage': photoStage,
          'photos': queued,
        },
      );
      final now = DateTime.now();
      return queued.map((row) {
        final id = row['offline_id']?.toString() ?? '';
        return TaskPhotoData(
          id: id,
          taskId: taskId.trim(),
          storagePath: '',
          originalName: row['original_name']?.toString() ?? 'Фото',
          photoStage: photoStage,
          createdAt: now,
        );
      }).toList(growable: false);
    }
  }

  static Future<void> deleteTaskPhoto(TaskPhotoData photo) async {
    try {
      await TaskPhotoRepository.deletePhoto(photo);
      await OfflineSyncService.markSynced();
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      await OfflineSyncService.enqueue(
        kind: 'task.photo.delete',
        dedupeKey: photo.id,
        payload: <String, dynamic>{
          'id': photo.id,
          'storage_path': photo.storagePath,
        },
      );
    }
  }

  static Future<String> createTaskPhotoSignedUrl(TaskPhotoData photo) {
    return TaskPhotoRepository.createSignedUrl(photo);
  }

  static Future<void> openTaskPhoto(TaskPhotoData photo) async {
    final url = await createTaskPhotoSignedUrl(photo);
    TaskPhotoBrowserService.openUrl(url);
  }
}

class TaskBatchCreateInput {
  final TaskItemData task;
  final List<String> assigneeIds;

  const TaskBatchCreateInput({required this.task, required this.assigneeIds});

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'task_date': TaskRepository._dateKey(task.date),
      'axes': task.axes.trim(),
      'work': task.work.trim(),
      'assignee_ids': TaskAssigneeRepository.cleanIdSet(assigneeIds).toList(),
      'milestone_id': task.milestoneId?.trim(),
      'checklist_item_id': task.checklistItemId?.trim(),
    };
  }
}

class _TaskListCacheEntry {
  final List<TaskItemData> tasks;
  final DateTime createdAt;

  const _TaskListCacheEntry({required this.tasks, required this.createdAt});
}
