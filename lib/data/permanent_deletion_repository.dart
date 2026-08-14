import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_data_sync.dart';
import 'attendance_repository.dart';
import 'employee_archive_repository.dart';
import 'employee_repository.dart';
import 'object_repository.dart';
import 'payment_repository.dart';
import 'task_repository.dart';

class PermanentDeletionResult {
  final List<String> cleanupWarnings;

  const PermanentDeletionResult({this.cleanupWarnings = const <String>[]});

  bool get hasWarnings => cleanupWarnings.isNotEmpty;
}

class PermanentDeletionRepository {
  static final _client = Supabase.instance.client;

  static const int _storageChunkSize = 100;

  static List<String> _stringList(dynamic value) {
    if (value is! List) return <String>[];

    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  static Map<String, dynamic> _mapFromRpc(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);

    return <String, dynamic>{};
  }

  static Future<List<String>> _removeStoragePaths({
    required String bucket,
    required List<String> paths,
  }) async {
    if (paths.isEmpty) return <String>[];

    final warnings = <String>[];

    for (var start = 0; start < paths.length; start += _storageChunkSize) {
      final end = math.min(start + _storageChunkSize, paths.length);
      final chunk = paths.sublist(start, end);

      try {
        await _client.storage.from(bucket).remove(chunk);
      } catch (_) {
        warnings.add(
          'Не удалось очистить ${chunk.length} файл(а/ов) из хранилища $bucket',
        );
      }
    }

    return warnings;
  }

  static Future<List<String>> _cleanupStorage(
    Map<String, dynamic> manifest,
  ) async {
    final warnings = <String>[];

    warnings.addAll(
      await _removeStoragePaths(
        bucket: 'employee-documents',
        paths: _stringList(manifest['employee_document_paths']),
      ),
    );
    warnings.addAll(
      await _removeStoragePaths(
        bucket: 'payment-receipts',
        paths: _stringList(manifest['payment_receipt_paths']),
      ),
    );
    warnings.addAll(
      await _removeStoragePaths(
        bucket: 'task-photos',
        paths: _stringList(manifest['task_photo_paths']),
      ),
    );

    return warnings;
  }

  static void _clearCaches() {
    EmployeeArchiveRepository.clearCache();
    EmployeeRepository.clearCache();
    ObjectRepository.clearCache();
    AttendanceRepository.clearCache();
    PaymentRepository.clearCache();
    TaskRepository.clearTaskListCache();
  }

  static Future<PermanentDeletionResult> deleteArchivedEmployee(
    String employeeId,
  ) async {
    return deleteArchivedEmployees(<String>[employeeId]);
  }

  static Future<PermanentDeletionResult> deleteArchivedEmployees(
    Iterable<String> employeeIds,
  ) async {
    final ids = employeeIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) throw Exception('Не найдены ID сотрудников');

    final response = await _client.rpc(
      'permanently_delete_archived_employees',
      params: <String, dynamic>{'p_employee_ids': ids},
    );
    final manifest = _mapFromRpc(response);
    final warnings = await _cleanupStorage(manifest);

    _clearCaches();
    AppDataSync.notifyLocal(
      const <AppDataDomain>{
        AppDataDomain.employees,
        AppDataDomain.attendance,
        AppDataDomain.payments,
      },
      context: <String, dynamic>{
        'table': 'employees',
        'employee_ids': ids,
        'permanently_deleted': true,
      },
    );

    return PermanentDeletionResult(cleanupWarnings: warnings);
  }

  static Future<PermanentDeletionResult> deleteArchivedObject(
    String objectName,
  ) async {
    return deleteArchivedObjects(<String>[objectName]);
  }

  static Future<PermanentDeletionResult> deleteArchivedObjects(
    Iterable<String> objectNames,
  ) async {
    final names = objectNames
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (names.isEmpty) throw Exception('Не найдены объекты');

    final response = await _client.rpc(
      'permanently_delete_archived_objects',
      params: <String, dynamic>{'p_names': names},
    );
    final manifest = _mapFromRpc(response);

    final warnings = await _cleanupStorage(manifest);

    _clearCaches();
    AppDataSync.notifyLocal(
      const <AppDataDomain>{
        AppDataDomain.objects,
        AppDataDomain.employees,
        AppDataDomain.attendance,
        AppDataDomain.payments,
        AppDataDomain.tasks,
      },
      context: <String, dynamic>{
        'table': 'objects',
        'object_names': names,
        'permanently_deleted': true,
      },
    );

    return PermanentDeletionResult(cleanupWarnings: warnings);
  }
}
