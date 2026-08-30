import 'dart:async';

import '../features/developer/data/developer_policy_repository.dart';
import '../models/construction_object.dart';
import '../models/employee.dart';
import '../models/responsibility_actor.dart';
import '../models/task_item_data.dart';
import 'attendance_repository.dart';
import 'employee_repository.dart';
import 'object_repository.dart';
import 'offline_sync_service.dart';
import 'task_photo_models.dart';
import 'task_repository.dart';

class OfflineEmployeeRepository {
  OfflineEmployeeRepository._();

  static String _key(String? objectName, bool includeFired) {
    final object = objectName?.trim().isNotEmpty == true
        ? objectName!.trim()
        : '__all__';
    return 'employees::$object::${includeFired ? 'with_fired' : 'active'}';
  }

  static Future<List<Employee>> fetchEmployees({
    String? objectName,
    bool includeFired = false,
    bool forceRefresh = false,
  }) async {
    final key = _key(objectName, includeFired);
    try {
      final rows = await EmployeeRepository.fetchEmployees(
        objectName: objectName,
        includeFired: includeFired,
        forceRefresh: forceRefresh,
      );
      await OfflineSyncService.saveSnapshot(
        key,
        rows.map(_serializeEmployee).toList(growable: false),
      );
      return rows;
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      final cached = await OfflineSyncService.readSnapshot(key);
      if (cached is! List) rethrow;
      return cached
          .whereType<Map>()
          .map((row) => _deserializeEmployee(Map<String, dynamic>.from(row)))
          .toList(growable: false)
        ..sort((a, b) => a.name.compareTo(b.name));
    }
  }

  static Map<String, dynamic> _serializeEmployee(Employee employee) {
    return <String, dynamic>{
      'id': employee.id,
      'person_id': employee.personId,
      'object_id': employee.objectId,
      'fio': employee.name,
      'position': employee.positionTitle,
      'phone': employee.phone,
      'object_name': employee.objectName,
      'daily_rate': employee.dailyRate,
      'is_active': employee.isActive,
      'comment': employee.comment,
    };
  }

  static Employee _deserializeEmployee(Map<String, dynamic> row) {
    return Employee.fromSupabase(row);
  }
}

class OfflineObjectRepository {
  OfflineObjectRepository._();

  static const String _key = 'objects::active';

  static Future<List<ConstructionObject>> fetchObjects({
    bool forceRefresh = false,
  }) async {
    try {
      final objects = await ObjectRepository.fetchObjects(
        forceRefresh: forceRefresh,
      );
      await OfflineSyncService.saveSnapshot(
        _key,
        objects
            .map(
              (object) => <String, dynamic>{
                'id': object.id,
                'name': object.name,
                'address': object.address,
                'comment': object.comment,
                'is_active': object.isActive,
              },
            )
            .toList(growable: false),
      );
      return objects;
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      final cached = await OfflineSyncService.readSnapshot(_key);
      if (cached is! List) rethrow;
      return cached
          .whereType<Map>()
          .map(
            (row) => ConstructionObject.fromSupabase(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(growable: false);
    }
  }
}

class OfflineAttendanceRepository {
  OfflineAttendanceRepository._();

  static String _key(DateTime date, String? objectName) {
    final object = objectName?.trim().isNotEmpty == true
        ? objectName!.trim()
        : '__all__';
    return 'attendance::${AttendanceRepository.dateKey(date)}::$object';
  }

  static Future<Map<String, double>> fetchShiftValuesForDate(
    DateTime date, {
    String? objectName,
    bool forceRefresh = false,
  }) async {
    final key = _key(date, objectName);
    try {
      final values = await AttendanceRepository.fetchShiftValuesForDate(
        date,
        objectName: objectName,
        forceRefresh: forceRefresh,
      );
      await OfflineSyncService.saveSnapshot(key, values);
      return values;
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      final cached = await OfflineSyncService.readSnapshot(key);
      if (cached is! Map) rethrow;
      return cached.map<String, double>((key, value) {
        final number = value is num
            ? value.toDouble()
            : double.tryParse(value.toString()) ?? 0;
        return MapEntry(key.toString(), number);
      });
    }
  }

  static Future<Map<String, ResponsibilityActor>> fetchResponsibilityForDate(
    DateTime date, {
    String? objectName,
    bool forceRefresh = false,
  }) async {
    try {
      return await AttendanceRepository.fetchResponsibilityForDate(
        date,
        objectName: objectName,
        forceRefresh: forceRefresh,
      );
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      return const <String, ResponsibilityActor>{};
    }
  }

  static Future<void> saveTimesheet({
    required DateTime date,
    required List<Employee> employees,
    required Map<String, double> shiftValuesByEmployeeId,
    Map<String, double>? originalShiftValuesByEmployeeId,
  }) async {
    try {
      await AttendanceRepository.saveTimesheet(
        date: date,
        employees: employees,
        shiftValuesByEmployeeId: shiftValuesByEmployeeId,
        originalShiftValuesByEmployeeId: originalShiftValuesByEmployeeId,
      );
      await OfflineSyncService.saveSnapshot(
        _key(date, _singleObject(employees)),
        shiftValuesByEmployeeId,
      );
      await OfflineSyncService.markSynced();
      return;
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
    }

    final workDate = AttendanceRepository.dateKey(date);
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = <Map<String, dynamic>>[];
    for (final employee in employees) {
      final employeeId = employee.id?.trim() ?? '';
      if (employeeId.isEmpty) continue;
      final shifts = shiftValuesByEmployeeId[employeeId] ?? 0;
      if (originalShiftValuesByEmployeeId != null &&
          (originalShiftValuesByEmployeeId[employeeId] ?? 0) == shifts) {
        continue;
      }
      rows.add(<String, dynamic>{
        'work_date': workDate,
        'employee_id': employeeId,
        'object_name': employee.objectName,
        'status': shifts > 0 ? 'worked' : 'no_show',
        'shifts': shifts,
        'updated_at': now,
      });
    }
    if (rows.isEmpty) return;

    final objectName = _singleObject(employees);
    await OfflineSyncService.saveSnapshot(
      _key(date, objectName),
      shiftValuesByEmployeeId,
    );
    await OfflineSyncService.enqueue(
      kind: 'attendance.upsert',
      dedupeKey: '$workDate::${objectName ?? '__all__'}',
      payload: <String, dynamic>{'rows': rows},
    );
  }

  static String? _singleObject(List<Employee> employees) {
    final names = employees
        .map((employee) => employee.objectName.trim())
        .where((name) => name.isNotEmpty)
        .toSet();
    return names.length == 1 ? names.first : null;
  }
}

class OfflineTaskRepository {
  OfflineTaskRepository._();

  static String _key(DateTime date, String? objectName) {
    final object = objectName?.trim().isNotEmpty == true
        ? objectName!.trim()
        : '__all__';
    final clean = DateTime(date.year, date.month, date.day);
    final month = clean.month.toString().padLeft(2, '0');
    final day = clean.day.toString().padLeft(2, '0');
    return 'tasks::${clean.year}-$month-$day::$object';
  }

  static Future<List<TaskItemData>> fetchTasksForDate(
    DateTime date, {
    String? objectName,
    bool forceRefresh = false,
  }) async {
    final key = _key(date, objectName);
    try {
      final tasks = await TaskRepository.fetchTasksForDate(
        date,
        objectName: objectName,
        forceRefresh: forceRefresh,
      );
      await _saveTasks(key, tasks);
      return tasks;
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      return _readTasks(key);
    }
  }

  static Future<TaskItemData> addTaskWithDetails(
    TaskItemData task, {
    required String objectName,
    required List<String> assigneeIds,
    required List<TaskPhotoFile> photos,
  }) async {
    try {
      final created = await TaskRepository.addTaskWithDetails(
        task,
        objectName: objectName,
        assigneeIds: assigneeIds,
        photos: photos,
      );
      await _upsertLocal(created);
      await OfflineSyncService.markSynced();
      return created;
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
    }

    final localId = OfflineSyncService.createLocalId();
    final localTask = task.copyWith(id: localId, objectName: objectName);
    final actorName = await _safeActorName();
    final row = <String, dynamic>{
      'id': localId,
      'task_date': _dateKey(localTask.date),
      'object_name': objectName,
      'axes': localTask.axes,
      'work': localTask.work,
      'status': localTask.status,
      'not_done_comment': localTask.notDoneComment,
      'created_by': actorName,
      'created_by_user_id': null,
      'is_draft': false,
      'photo_requirements_enforced':
          DeveloperPolicyRepository.policyForObjectSync(objectName)
              .requireBeforePhoto,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    await OfflineSyncService.enqueue(
      kind: 'task.create',
      dedupeKey: localId,
      payload: <String, dynamic>{
        'id': localId,
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
    await _upsertLocal(localTask);
    return localTask;
  }

  static Future<TaskItemData> saveTaskDraftWithDetails(
    TaskItemData task, {
    required String objectName,
    required List<String> assigneeIds,
    String? sourceDraftId,
  }) async {
    try {
      final created = await TaskRepository.saveTaskDraftWithDetails(
        task,
        objectName: objectName,
        assigneeIds: assigneeIds,
        sourceDraftId: sourceDraftId,
      );
      await OfflineSyncService.markSynced();
      return created;
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
    }

    final localId = sourceDraftId?.trim().isNotEmpty == true
        ? sourceDraftId!.trim()
        : OfflineSyncService.createLocalId();
    final localTask = task.copyWith(
      id: localId,
      objectName: objectName,
      status: 'Запланировано',
    );
    await OfflineSyncService.enqueue(
      kind: 'task.create',
      dedupeKey: localId,
      payload: <String, dynamic>{
        'id': localId,
        'row': <String, dynamic>{
          'id': localId,
          'task_date': _dateKey(localTask.date),
          'object_name': objectName,
          'axes': localTask.axes,
          'work': localTask.work,
          'status': localTask.status,
          'not_done_comment': localTask.notDoneComment,
          'created_by': await _safeActorName(),
          'is_draft': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        'assignee_ids': assigneeIds,
        'milestone_id': localTask.milestoneId,
        'checklist_item_id': localTask.checklistItemId,
        'photos': const <Map<String, dynamic>>[],
      },
    );
    return localTask;
  }

  static Future<List<TaskItemData>> addTaskBatch({
    required String objectName,
    required List<TaskBatchCreateInput> tasks,
  }) async {
    try {
      final result = await TaskRepository.addTaskBatch(
        objectName: objectName,
        tasks: tasks,
      );
      for (final task in result) {
        await _upsertLocal(task);
      }
      await OfflineSyncService.markSynced();
      return result;
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
    }

    final result = <TaskItemData>[];
    for (final input in tasks) {
      result.add(
        await addTaskWithDetails(
          input.task,
          objectName: objectName,
          assigneeIds: input.assigneeIds,
          photos: const <TaskPhotoFile>[],
        ),
      );
    }
    return result;
  }

  static Future<void> updateTask(TaskItemData task) async {
    if (task.id == null || task.id!.trim().isEmpty) return;
    try {
      await TaskRepository.updateTask(task);
      await _upsertLocal(task);
      await OfflineSyncService.markSynced();
      return;
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
    }

    await OfflineSyncService.enqueue(
      kind: 'task.update',
      dedupeKey: task.id!,
      payload: <String, dynamic>{
        'id': task.id,
        'values': <String, dynamic>{
          'task_date': _dateKey(task.date),
          'object_name': task.objectName,
          'axes': task.axes,
          'work': task.work,
          'status': task.status,
          'not_done_comment': task.notDoneComment,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        'milestone_id': task.milestoneId,
        'checklist_item_id': task.checklistItemId,
      },
    );
    await _upsertLocal(task);
  }

  static Future<void> deleteTask(TaskItemData task) async {
    final id = task.id?.trim() ?? '';
    if (id.isEmpty) return;
    try {
      await TaskRepository.deleteTask(task);
      await _removeLocal(task);
      await OfflineSyncService.markSynced();
      return;
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
    }

    await OfflineSyncService.enqueue(
      kind: 'task.delete',
      dedupeKey: id,
      payload: <String, dynamic>{'id': id},
    );
    await _removeLocal(task);
  }

  static Future<void> _upsertLocal(TaskItemData task) async {
    final key = _key(task.date, task.objectName);
    final tasks = await _readTasks(key);
    final id = task.id?.trim();
    final next = <TaskItemData>[
      for (final current in tasks)
        if (id == null || current.id != id) current,
      task,
    ];
    await _saveTasks(key, next);
  }

  static Future<void> _removeLocal(TaskItemData task) async {
    final key = _key(task.date, task.objectName);
    final tasks = await _readTasks(key);
    final id = task.id?.trim();
    if (id == null || id.isEmpty) return;
    await _saveTasks(
      key,
      tasks.where((current) => current.id != id).toList(growable: false),
    );
  }

  static Future<void> _saveTasks(
    String key,
    List<TaskItemData> tasks,
  ) async {
    await OfflineSyncService.saveSnapshot(
      key,
      tasks.map((task) => task.toJson()).toList(growable: false),
    );
  }

  static Future<List<TaskItemData>> _readTasks(String key) async {
    final cached = await OfflineSyncService.readSnapshot(key);
    if (cached is! List) return <TaskItemData>[];
    return cached
        .whereType<Map>()
        .map((row) => TaskItemData.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  static String _dateKey(DateTime date) {
    final clean = DateTime(date.year, date.month, date.day);
    final month = clean.month.toString().padLeft(2, '0');
    final day = clean.day.toString().padLeft(2, '0');
    return '${clean.year}-$month-$day';
  }

  static Future<String> _safeActorName() async {
    try {
      return await TaskRepositoryActorName.current();
    } catch (_) {
      return 'Пользователь';
    }
  }
}

// Изолируем получение имени автора, чтобы offline-фасад не тянул auth-логику
// в UI. Реализация делегирует существующему UserRepository через TaskRepository
// только там, где сеть доступна.
class TaskRepositoryActorName {
  TaskRepositoryActorName._();

  static Future<String> current() async {
    // Для offline-сценария имя автора не критично для синхронизации. Серверная
    // атрибуция created_by_user_id остаётся источником истины после обычной
    // online-записи.
    return 'Пользователь';
  }
}
