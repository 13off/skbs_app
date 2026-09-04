import '../models/construction_object.dart';
import '../models/employee.dart';
import '../models/responsibility_actor.dart';
import 'attendance_repository.dart';
import 'employee_repository.dart';
import 'object_repository.dart';
import 'offline_sync_service.dart';

const Duration _fieldNetworkDeadline = Duration(seconds: 3);

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
      ).timeout(_fieldNetworkDeadline);
      await OfflineSyncService.saveSnapshot(
        key,
        rows.map(_serializeEmployee).toList(growable: false),
      );
      await OfflineSyncService.markSynced();
      return rows;
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      final cached = await OfflineSyncService.readSnapshot(key);
      if (cached is! List) rethrow;
      return cached
          .whereType<Map>()
          .map((row) => Employee.fromSupabase(Map<String, dynamic>.from(row)))
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
      ).timeout(_fieldNetworkDeadline);
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
      await OfflineSyncService.markSynced();
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

  static Future<List<String>> fetchObjectNames({
    bool forceRefresh = false,
  }) async {
    final objects = await fetchObjects(forceRefresh: forceRefresh);
    final result = objects
        .where((object) => object.isActive)
        .map((object) => object.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    return result;
  }
}

class OfflineAttendanceRepository {
  OfflineAttendanceRepository._();

  static String _objectKey(String? objectName) {
    return objectName?.trim().isNotEmpty == true
        ? objectName!.trim()
        : '__all__';
  }

  static String _key(DateTime date, String? objectName) {
    return 'attendance::${AttendanceRepository.dateKey(date)}::${_objectKey(objectName)}';
  }

  static String _responsibilityKey(DateTime date, String? objectName) {
    return 'attendance_responsibility::${AttendanceRepository.dateKey(date)}::${_objectKey(objectName)}';
  }

  static String _queueKey(DateTime date, String? objectName) {
    return '${AttendanceRepository.dateKey(date)}::${_objectKey(objectName)}';
  }

  static Map<String, double> _valuesFromSnapshot(dynamic cached) {
    if (cached is! Map) return <String, double>{};
    return cached.map<String, double>((key, value) {
      final number = value is num
          ? value.toDouble()
          : double.tryParse(value.toString()) ?? 0;
      return MapEntry(key.toString(), number);
    });
  }

  static Map<String, dynamic> _actorToSnapshot(ResponsibilityActor actor) {
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

  static Future<Map<String, double>> fetchShiftValuesForDate(
    DateTime date, {
    String? objectName,
    bool forceRefresh = false,
  }) async {
    final key = _key(date, objectName);
    try {
      final serverValues = await AttendanceRepository.fetchShiftValuesForDate(
        date,
        objectName: objectName,
        forceRefresh: forceRefresh,
      ).timeout(_fieldNetworkDeadline);
      var values = serverValues;
      if (await OfflineSyncService.hasPending(
        kind: 'attendance.upsert',
        dedupeKey: _queueKey(date, objectName),
      )) {
        final localValues = _valuesFromSnapshot(
          await OfflineSyncService.readSnapshot(key),
        );
        values = <String, double>{...serverValues, ...localValues};
      }
      await OfflineSyncService.saveSnapshot(key, values);
      await OfflineSyncService.markSynced();
      return values;
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      final cached = await OfflineSyncService.readSnapshot(key);
      if (cached is! Map) rethrow;
      return _valuesFromSnapshot(cached);
    }
  }

  static Future<Set<String>> fetchWorkedEmployeeIds(
    DateTime date, {
    String? objectName,
    bool forceRefresh = false,
  }) async {
    final values = await fetchShiftValuesForDate(
      date,
      objectName: objectName,
      forceRefresh: forceRefresh,
    );
    return values.entries
        .where((entry) => entry.value > 0)
        .map((entry) => entry.key)
        .toSet();
  }

  static Future<Map<String, ResponsibilityActor>> fetchResponsibilityForDate(
    DateTime date, {
    String? objectName,
    bool forceRefresh = false,
  }) async {
    final key = _responsibilityKey(date, objectName);
    try {
      final result = await AttendanceRepository.fetchResponsibilityForDate(
        date,
        objectName: objectName,
        forceRefresh: forceRefresh,
      ).timeout(_fieldNetworkDeadline);
      await OfflineSyncService.saveSnapshot(
        key,
        result.map(
          (employeeId, actor) => MapEntry(
            employeeId,
            _actorToSnapshot(actor),
          ),
        ),
      );
      await OfflineSyncService.markSynced();
      return result;
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      final cached = await OfflineSyncService.readSnapshot(key);
      if (cached is! Map) return const <String, ResponsibilityActor>{};
      final result = <String, ResponsibilityActor>{};
      for (final entry in cached.entries) {
        final actor = _actorFromSnapshot(entry.value);
        if (actor != null) result[entry.key.toString()] = actor;
      }
      return result;
    }
  }

  static Future<void> saveTimesheet({
    required DateTime date,
    required List<Employee> employees,
    required Map<String, double> shiftValuesByEmployeeId,
    Map<String, double>? originalShiftValuesByEmployeeId,
  }) async {
    final objectName = _singleObject(employees);
    try {
      await AttendanceRepository.saveTimesheet(
        date: date,
        employees: employees,
        shiftValuesByEmployeeId: shiftValuesByEmployeeId,
        originalShiftValuesByEmployeeId: originalShiftValuesByEmployeeId,
      ).timeout(_fieldNetworkDeadline);
      await OfflineSyncService.saveSnapshot(
        _key(date, objectName),
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
    if (rows.isEmpty) {
      await OfflineSyncService.saveSnapshot(
        _key(date, objectName),
        shiftValuesByEmployeeId,
      );
      return;
    }

    await OfflineSyncService.saveSnapshot(
      _key(date, objectName),
      shiftValuesByEmployeeId,
    );
    await OfflineSyncService.enqueue(
      kind: 'attendance.upsert',
      dedupeKey: _queueKey(date, objectName),
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
