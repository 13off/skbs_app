import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'attendance_repository.dart';
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
    EmployeeRepository.clearCache();
    ObjectRepository.clearCache();
    AttendanceRepository.clearCache();
    PaymentRepository.clearCache();
    TaskRepository.clearTaskListCache();
  }

  static Future<PermanentDeletionResult> deleteArchivedEmployee(
    String employeeId,
  ) async {
    final cleanEmployeeId = employeeId.trim();

    if (cleanEmployeeId.isEmpty) {
      throw Exception('Не найден ID сотрудника');
    }

    final response = await _client.rpc(
      'permanently_delete_employee',
      params: <String, dynamic>{'p_employee_id': cleanEmployeeId},
    );
    final manifest = _mapFromRpc(response);
    final warnings = await _cleanupStorage(manifest);

    _clearCaches();

    return PermanentDeletionResult(cleanupWarnings: warnings);
  }

  static Future<PermanentDeletionResult> deleteArchivedObject(
    String objectName,
  ) async {
    final cleanName = objectName.trim();

    if (cleanName.isEmpty) {
      throw Exception('Не найден объект');
    }

    final response = await _client.rpc(
      'archived_object_delete_manifest',
      params: <String, dynamic>{'p_name': cleanName},
    );
    final manifest = _mapFromRpc(response);
    final now = DateTime.now().toUtc().toIso8601String();

    // Объект удаляется последним. Если один из предыдущих шагов завершится
    // ошибкой, архивная запись останется и очистку можно будет повторить.
    await _client
        .from('user_profiles')
        .update(<String, dynamic>{'object_name': null, 'updated_at': now})
        .eq('object_name', cleanName);
    await _client
        .from('app_notification_clears')
        .delete()
        .eq('object_name', cleanName);
    await _client
        .from('app_notifications')
        .delete()
        .eq('object_name', cleanName);
    await _client.from('tasks').delete().eq('object_name', cleanName);
    await _client.from('attendance').delete().eq('object_name', cleanName);
    await _client.from('employees').delete().eq('object_name', cleanName);
    await _client.from('objects').delete().eq('name', cleanName);

    final warnings = await _cleanupStorage(manifest);

    _clearCaches();

    return PermanentDeletionResult(cleanupWarnings: warnings);
  }
}
