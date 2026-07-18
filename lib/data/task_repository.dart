import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

import '../features/auth/data/user_repository.dart';
import '../features/developer/data/developer_policy_repository.dart';
import '../models/task_item_data.dart';
import 'app_data_sync.dart';
import 'image_compression_service.dart';

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

class TaskPhotoData {
  final String id;
  final String taskId;
  final String storagePath;
  final String originalName;
  final String photoStage;
  final DateTime createdAt;

  const TaskPhotoData({
    required this.id,
    required this.taskId,
    required this.storagePath,
    required this.originalName,
    required this.photoStage,
    required this.createdAt,
  });

  bool get isBefore => photoStage == 'before';
  bool get isAfter => photoStage == 'after';

  factory TaskPhotoData.fromSupabase(Map<String, dynamic> json) {
    return TaskPhotoData(
      id: json['id']?.toString() ?? '',
      taskId: json['task_id']?.toString() ?? '',
      storagePath: json['storage_path']?.toString() ?? '',
      originalName: json['original_name']?.toString() ?? 'Фото',
      photoStage: json['photo_stage']?.toString() == 'after'
          ? 'after'
          : 'before',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class TaskPhotoFile {
  final String originalName;
  final String contentType;
  final String extension;
  final Uint8List bytes;

  const TaskPhotoFile({
    required this.originalName,
    required this.contentType,
    required this.extension,
    required this.bytes,
  });
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
  static const taskPhotosBucket = 'task-photos';
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
    final dotIndex = name.lastIndexOf('.');

    if (dotIndex == -1 || dotIndex == name.length - 1) return '';

    final extension = name.substring(dotIndex + 1).toLowerCase();

    final allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

    if (!allowedExtensions.contains(extension)) return '';

    return extension;
  }

  static Uint8List bytesFromReaderResult(Object? result) {
    if (result is Uint8List) return result;

    if (result is ByteBuffer) {
      return Uint8List.view(result);
    }

    throw Exception('Не удалось прочитать фото');
  }

  static String safePhotoStoragePath({
    required String taskId,
    required String photoStage,
    required TaskPhotoFile photo,
    required int index,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = photo.extension.isEmpty ? 'jpg' : photo.extension;

    return '$taskId/$photoStage/${timestamp}_$index.$extension';
  }

  static Future<List<TaskPhotoFile>> pickPhotoFiles() async {
    final input = html.FileUploadInputElement()
      ..multiple = true
      ..accept = 'image/jpeg,image/png,image/webp,.jpg,.jpeg,.png,.webp';

    input.click();

    await input.onChange.first;

    final files = input.files;

    if (files == null || files.isEmpty) {
      return <TaskPhotoFile>[];
    }

    final photos = <TaskPhotoFile>[];

    for (final file in files) {
      final extension = extensionFromFileName(file.name);

      if (extension.isEmpty) {
        throw Exception(
          'Можно загрузить только JPG, PNG или WEBP: ${file.name}',
        );
      }

      final reader = html.FileReader();

      reader.readAsArrayBuffer(file);

      await reader.onLoad.first;

      final originalBytes = bytesFromReaderResult(reader.result);
      final compressedPhoto =
          await ImageCompressionService.compressHtmlImageFile(
            file: file,
            originalBytes: originalBytes,
            originalName: file.name,
            maxDimension: 1600,
            jpegQuality: 0.82,
          );

      photos.add(
        TaskPhotoFile(
          originalName: file.name,
          contentType: compressedPhoto.contentType,
          extension: compressedPhoto.extension.isEmpty
              ? extension
              : compressedPhoto.extension,
          bytes: compressedPhoto.bytes,
        ),
      );
    }

    return photos;
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
        final paths = draftPhotos
            .map((photo) => photo.storagePath)
            .where((path) => path.trim().isNotEmpty)
            .toList();
        if (paths.isNotEmpty) {
          await _client.storage.from(taskPhotosBucket).remove(paths);
        }
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

    return rows.map<TaskAssigneeData>((row) {
      return TaskAssigneeData.fromSupabase(row);
    }).toList();
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

    final rows = cleanIds.map((employeeId) {
      return {'task_id': taskId, 'employee_id': employeeId};
    }).toList();

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

  static Future<List<TaskPhotoData>> fetchTaskPhotos(String taskId) async {
    final rows = await _client
        .from('task_photos')
        .select(
          'id, task_id, storage_path, original_name, photo_stage, created_at',
        )
        .eq('task_id', taskId)
        .order('created_at', ascending: false);

    return rows.map<TaskPhotoData>((row) {
      return TaskPhotoData.fromSupabase(row);
    }).toList();
  }

  static Future<List<TaskPhotoData>> uploadPhotosForTask({
    required String taskId,
    required List<TaskPhotoFile> photos,
    required String photoStage,
  }) async {
    if (photos.isEmpty) return <TaskPhotoData>[];
    if (photoStage != 'before' && photoStage != 'after') {
      throw ArgumentError.value(photoStage, 'photoStage');
    }

    final rowsToInsert = <Map<String, String>>[];
    final uploadedPaths = <String>[];

    try {
      for (var i = 0; i < photos.length; i++) {
        final photo = photos[i];
        final path = safePhotoStoragePath(
          taskId: taskId,
          photoStage: photoStage,
          photo: photo,
          index: i + 1,
        );

        await _client.storage
            .from(taskPhotosBucket)
            .uploadBinary(
              path,
              photo.bytes,
              fileOptions: FileOptions(
                contentType: photo.contentType,
                upsert: false,
              ),
            );

        uploadedPaths.add(path);
        rowsToInsert.add({
          'task_id': taskId,
          'storage_path': path,
          'original_name': photo.originalName,
          'photo_stage': photoStage,
        });
      }

      final rows = await _client
          .from('task_photos')
          .insert(rowsToInsert)
          .select(
            'id, task_id, storage_path, original_name, photo_stage, created_at',
          );

      return rows.map<TaskPhotoData>((row) {
        return TaskPhotoData.fromSupabase(row);
      }).toList();
    } catch (_) {
      if (uploadedPaths.isNotEmpty) {
        try {
          await _client.storage.from(taskPhotosBucket).remove(uploadedPaths);
        } catch (_) {
          // Служебная очистка удалит оставшиеся файлы.
        }
      }
      rethrow;
    }
  }

  static Future<void> deleteTaskPhoto(TaskPhotoData photo) async {
    final deletedRows = await _client
        .from('task_photos')
        .delete()
        .eq('id', photo.id)
        .eq('task_id', photo.taskId)
        .select('id');

    if (deletedRows.isEmpty) {
      throw Exception('Фото уже удалено или редактирование закрыто');
    }

    try {
      await _client.storage.from(taskPhotosBucket).remove([photo.storagePath]);
    } catch (_) {
      // Запись уже удалена. Оставшийся файл можно убрать служебной очисткой.
    }

    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.tasks},
      context: <String, dynamic>{
        'table': 'task_photos',
        'task_id': photo.taskId,
      },
    );
  }

  static Future<String> createTaskPhotoSignedUrl(TaskPhotoData photo) async {
    return _client.storage
        .from(taskPhotosBucket)
        .createSignedUrl(photo.storagePath, 60 * 10);
  }

  static Future<void> openTaskPhoto(TaskPhotoData photo) async {
    final url = await createTaskPhotoSignedUrl(photo);

    html.window.open(url, '_blank');
  }
}

class _TaskListCacheEntry {
  final List<TaskItemData> tasks;
  final DateTime createdAt;

  const _TaskListCacheEntry({required this.tasks, required this.createdAt});
}
