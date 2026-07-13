import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

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
  final DateTime createdAt;

  const TaskPhotoData({
    required this.id,
    required this.taskId,
    required this.storagePath,
    required this.originalName,
    required this.createdAt,
  });

  factory TaskPhotoData.fromSupabase(Map<String, dynamic> json) {
    return TaskPhotoData(
      id: json['id']?.toString() ?? '',
      taskId: json['task_id']?.toString() ?? '',
      storagePath: json['storage_path']?.toString() ?? '',
      originalName: json['original_name']?.toString() ?? 'Фото',
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
    required TaskPhotoFile photo,
    required int index,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = photo.extension.isEmpty ? 'jpg' : photo.extension;

    return '$taskId/${timestamp}_$index.$extension';
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
              .order('created_at', ascending: true)
        : await _client
              .from('tasks')
              .select(
                'id, task_date, object_name, axes, work, status, not_done_comment',
              )
              .eq('task_date', _dateKey(date))
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
          final filteredRows = cleanObject == null
              ? rows
              : rows.where((row) {
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
    final row = await _client
        .from('tasks')
        .insert({
          'task_date': _dateKey(task.date),
          'object_name': objectName,
          'axes': task.axes,
          'work': task.work,
          'status': task.status,
          'not_done_comment': task.notDoneComment,
          'created_by': 'Илья',
        })
        .select(
          'id, task_date, object_name, axes, work, status, not_done_comment',
        )
        .single();

    clearTaskListCache();
    final createdTask = TaskItemData.fromSupabase(row);
    _notifyTasksChanged(createdTask);

    return createdTask;
  }

  static Future<TaskItemData> addTaskWithDetails(
    TaskItemData task, {
    required String objectName,
    required List<String> assigneeIds,
    required List<TaskPhotoFile> photos,
  }) async {
    final createdTask = await addTask(task, objectName: objectName);
    final taskId = createdTask.id;

    if (taskId == null || taskId.isEmpty) {
      return createdTask;
    }

    await saveTaskAssignees(taskId: taskId, assigneeIds: assigneeIds);

    if (photos.isNotEmpty) {
      await uploadPhotosForTask(taskId: taskId, photos: photos);
    }

    return createdTask;
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
        .select('id, task_id, storage_path, original_name, created_at')
        .eq('task_id', taskId)
        .order('created_at', ascending: false);

    return rows.map<TaskPhotoData>((row) {
      return TaskPhotoData.fromSupabase(row);
    }).toList();
  }

  static Future<List<TaskPhotoData>> uploadPhotosForTask({
    required String taskId,
    required List<TaskPhotoFile> photos,
  }) async {
    if (photos.isEmpty) return <TaskPhotoData>[];

    final rowsToInsert = <Map<String, String>>[];

    for (var i = 0; i < photos.length; i++) {
      final photo = photos[i];
      final path = safePhotoStoragePath(
        taskId: taskId,
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

      rowsToInsert.add({
        'task_id': taskId,
        'storage_path': path,
        'original_name': photo.originalName,
      });
    }

    final rows = await _client
        .from('task_photos')
        .insert(rowsToInsert)
        .select('id, task_id, storage_path, original_name, created_at');

    return rows.map<TaskPhotoData>((row) {
      return TaskPhotoData.fromSupabase(row);
    }).toList();
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
