import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/timesheet/models/timesheet_absence_reason.dart';
import '../models/employee.dart';
import 'app_data_sync.dart';
import 'attendance_repository.dart';
import 'offline_sync_service.dart';

class OfflineAttendanceReasonRepository {
  OfflineAttendanceReasonRepository._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const Duration _fieldNetworkDeadline = Duration(seconds: 3);

  static String _objectKey(String? objectName) {
    final clean = objectName?.trim();
    return clean == null || clean.isEmpty ? '__all__' : clean;
  }

  static String _snapshotKey(DateTime date, String? objectName) {
    return 'attendance_reasons::${AttendanceRepository.dateKey(date)}::${_objectKey(objectName)}';
  }

  static String _queueKey(DateTime date, String? objectName) {
    return '${AttendanceRepository.dateKey(date)}::${_objectKey(objectName)}';
  }

  static String? _singleObject(List<Employee> employees) {
    final names = employees
        .map((employee) => employee.objectName.trim())
        .where((name) => name.isNotEmpty)
        .toSet();
    return names.length == 1 ? names.first : null;
  }

  static Map<String, String> _reasonsFromSnapshot(dynamic cached) {
    if (cached is! Map) return <String, String>{};
    final result = <String, String>{};
    for (final entry in cached.entries) {
      final reason = TimesheetAbsenceReason.normalize(entry.value?.toString());
      if (reason != null) result[entry.key.toString()] = reason;
    }
    return result;
  }

  static Future<Map<String, String>> fetchReasonsForDate(
    DateTime date, {
    String? objectName,
  }) async {
    final snapshotKey = _snapshotKey(date, objectName);
    final cleanObject = objectName?.trim();
    try {
      dynamic query = _client
          .from('attendance')
          .select('employee_id,absence_reason')
          .eq('work_date', AttendanceRepository.dateKey(date))
          .isFilter('deleted_at', null);
      if (cleanObject != null && cleanObject.isNotEmpty) {
        query = query.eq('object_name', cleanObject);
      }
      final rawRows = await (query as dynamic).timeout(_fieldNetworkDeadline);
      final serverReasons = <String, String>{};
      for (final raw in (rawRows as List<dynamic>).whereType<Map>()) {
        final row = Map<String, dynamic>.from(raw);
        final employeeId = row['employee_id']?.toString().trim() ?? '';
        final reason = TimesheetAbsenceReason.normalize(
          row['absence_reason']?.toString(),
        );
        if (employeeId.isNotEmpty && reason != null) {
          serverReasons[employeeId] = reason;
        }
      }

      var result = serverReasons;
      if (await OfflineSyncService.hasPending(
        kind: 'attendance.upsert',
        dedupeKey: _queueKey(date, objectName),
      )) {
        final localReasons = _reasonsFromSnapshot(
          await OfflineSyncService.readSnapshot(snapshotKey),
        );
        result = <String, String>{...serverReasons, ...localReasons};
      }
      await OfflineSyncService.saveSnapshot(snapshotKey, result);
      await OfflineSyncService.markSynced();
      return result;
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      final cached = await OfflineSyncService.readSnapshot(snapshotKey);
      if (cached is! Map) rethrow;
      return _reasonsFromSnapshot(cached);
    }
  }

  static Future<void> saveReasons({
    required DateTime date,
    required List<Employee> employees,
    required Map<String, double> shiftValuesByEmployeeId,
    required Map<String, String> reasonsByEmployeeId,
    required Map<String, String> originalReasonsByEmployeeId,
  }) async {
    final objectName = _singleObject(employees);
    final rows = _changedRows(
      date: date,
      employees: employees,
      shiftValuesByEmployeeId: shiftValuesByEmployeeId,
      reasonsByEmployeeId: reasonsByEmployeeId,
      originalReasonsByEmployeeId: originalReasonsByEmployeeId,
    );
    final snapshotKey = _snapshotKey(date, objectName);

    if (rows.isEmpty) {
      await OfflineSyncService.saveSnapshot(snapshotKey, reasonsByEmployeeId);
      return;
    }

    try {
      await _client
          .from('attendance')
          .upsert(rows, onConflict: 'work_date,employee_id')
          .timeout(_fieldNetworkDeadline);
      await OfflineSyncService.saveSnapshot(snapshotKey, reasonsByEmployeeId);
      await OfflineSyncService.markSynced();
      AppDataSync.notifyLocal(
        const <AppDataDomain>{AppDataDomain.attendance},
        context: <String, dynamic>{
          'table': 'attendance',
          'work_date': AttendanceRepository.dateKey(date),
          'object_name': objectName,
        },
      );
      return;
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
    }

    await OfflineSyncService.saveSnapshot(snapshotKey, reasonsByEmployeeId);
    await OfflineSyncService.enqueue(
      kind: 'attendance.upsert',
      dedupeKey: _queueKey(date, objectName),
      payload: <String, dynamic>{'rows': rows},
    );
  }

  static List<Map<String, dynamic>> _changedRows({
    required DateTime date,
    required List<Employee> employees,
    required Map<String, double> shiftValuesByEmployeeId,
    required Map<String, String> reasonsByEmployeeId,
    required Map<String, String> originalReasonsByEmployeeId,
  }) {
    final workDate = AttendanceRepository.dateKey(date);
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = <Map<String, dynamic>>[];
    for (final employee in employees) {
      final employeeId = employee.id?.trim() ?? '';
      if (employeeId.isEmpty) continue;
      final shifts = shiftValuesByEmployeeId[employeeId] ?? 0;
      final reason = shifts > 0
          ? null
          : TimesheetAbsenceReason.normalize(reasonsByEmployeeId[employeeId]);
      final originalReason = TimesheetAbsenceReason.normalize(
        originalReasonsByEmployeeId[employeeId],
      );
      if (reason == originalReason) continue;
      rows.add(<String, dynamic>{
        'work_date': workDate,
        'employee_id': employeeId,
        'object_name': employee.objectName,
        'status': shifts > 0 ? 'worked' : 'no_show',
        'shifts': shifts,
        'absence_reason': reason,
        'updated_at': now,
      });
    }
    return rows;
  }
}
