import 'dart:async';

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/offline_sync_service.dart';

class WorkOrderRepository {
  static final _db = Supabase.instance.client;
  static const List<String> unitOptions = <String>['м³', 'м²', 'т', 'шт.', 'м.п.'];

  static String dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
  static String _planSnapshotKey(String taskId) => 'task_work_plan::${taskId.trim()}';

  static Future<Map<String, dynamic>?> plan(String taskId) async {
    final cleanTaskId = taskId.trim();
    final localRaw = await OfflineSyncService.readSnapshot(
      _planSnapshotKey(cleanTaskId),
    );
    if (localRaw is Map) {
      final local = Map<String, dynamic>.from(localRaw);
      if (local['pending'] == true) {
        unawaited(_pushPendingPlan(cleanTaskId, local));
        return local;
      }
    }

    try {
      final server = await _db
          .from('task_work_plans')
          .select()
          .eq('task_id', cleanTaskId)
          .maybeSingle();
      if (server != null) {
        await OfflineSyncService.saveSnapshot(
          _planSnapshotKey(cleanTaskId),
          <String, dynamic>{...server, 'pending': false},
        );
        return server;
      }
    } catch (_) {
      if (localRaw is Map) return Map<String, dynamic>.from(localRaw);
      rethrow;
    }

    if (localRaw is Map) return Map<String, dynamic>.from(localRaw);
    return null;
  }

  /// Stores the plan locally first and publishes it as soon as the local-first
  /// task-create mutation has reached Supabase. This keeps task creation fast
  /// on weak mobile connections without losing the entered plan.
  static Future<void> queuePlan({
    required String taskId,
    required double planned,
    required String unit,
    required DateTime taskDate,
  }) async {
    final cleanTaskId = taskId.trim();
    final cleanUnit = unit.trim();
    if (cleanTaskId.isEmpty || !planned.isFinite || planned < 0 || cleanUnit.isEmpty) {
      return;
    }
    final snapshot = <String, dynamic>{
      'task_id': cleanTaskId,
      'planned_quantity': planned,
      'unit': cleanUnit,
      'task_date': dateKey(taskDate),
      'pending': true,
    };
    await OfflineSyncService.saveSnapshot(_planSnapshotKey(cleanTaskId), snapshot);
    unawaited(_pushPendingPlan(cleanTaskId, snapshot));
  }

  static Future<void> _pushPendingPlan(
    String taskId,
    Map<String, dynamic> snapshot,
  ) async {
    final plannedRaw = snapshot['planned_quantity'];
    final planned = plannedRaw is num
        ? plannedRaw.toDouble()
        : double.tryParse(plannedRaw?.toString() ?? '');
    final unit = snapshot['unit']?.toString().trim() ?? '';
    final taskDate = DateTime.tryParse(snapshot['task_date']?.toString() ?? '') ??
        DateTime.now();
    if (planned == null || !planned.isFinite || planned < 0 || unit.isEmpty) return;

    for (var attempt = 0; attempt < 90; attempt += 1) {
      try {
        await OfflineSyncService.flush();
        final createPending = await OfflineSyncService.hasPending(
          kind: 'task.create',
          dedupeKey: taskId,
        );
        if (createPending) {
          await Future<void>.delayed(const Duration(seconds: 1));
          continue;
        }
        await save(
          taskId: taskId,
          planned: planned,
          unit: unit,
          date: taskDate,
          quantity: null,
          participants: const <Map<String, dynamic>>[],
        );
        await OfflineSyncService.saveSnapshot(
          _planSnapshotKey(taskId),
          <String, dynamic>{...snapshot, 'pending': false},
        );
        return;
      } catch (_) {
        if (attempt == 89) return;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }

  static Future<List<Map<String, dynamic>>> days(String taskId) async =>
      await _db
          .from('task_work_days')
          .select()
          .eq('task_id', taskId)
          .order('work_date');

  static Future<void> save({
    required String taskId,
    required double? planned,
    required String unit,
    required DateTime date,
    required double? quantity,
    required List<Map<String, dynamic>> participants,
  }) async {
    await _db.rpc(
      'save_task_work_day',
      params: {
        'p_task_id': taskId,
        'p_planned': planned,
        'p_unit': unit,
        'p_date': dateKey(date),
        'p_quantity': quantity,
        'p_participants': participants,
      },
    );
    if (planned != null && planned.isFinite && planned >= 0 && unit.trim().isNotEmpty) {
      await OfflineSyncService.saveSnapshot(
        _planSnapshotKey(taskId),
        <String, dynamic>{
          'task_id': taskId,
          'planned_quantity': planned,
          'unit': unit.trim(),
          'task_date': dateKey(date),
          'pending': false,
        },
      );
    }
  }

  static Future<void> deleteDay(String taskId, DateTime date) async {
    await _db
        .from('task_work_days')
        .delete()
        .eq('task_id', taskId)
        .eq('work_date', dateKey(date));
  }

  static Future<List<Map<String, dynamic>>> period(
    DateTime start,
    DateTime end,
    String? objectName,
  ) async {
    // Page explicitly: PostgREST's default row limit must not truncate a month.
    final result = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 500) {
      var query = _db
          .from('task_work_days')
          .select('*, tasks!inner(object_name, work, axes, status)')
          .gte('work_date', dateKey(start))
          .lte('work_date', dateKey(end));
      if (objectName != null && objectName.trim().isNotEmpty) {
        query = query.eq('tasks.object_name', objectName.trim());
      }
      final rows = await query
          .order('work_date')
          .order('task_id')
          .range(offset, offset + 499);
      result.addAll(rows);
      if (rows.length < 500) break;
    }
    return result;
  }
}

/// Allocate thousandths with largest remainders, preserving the day's total.
List<double> allocateWorkQuantity(double quantity, List<double> weights) {
  if (!quantity.isFinite ||
      quantity < 0 ||
      weights.isEmpty ||
      weights.any((w) => !w.isFinite || w < 0)) {
    throw ArgumentError('Некорректный объём или КТУ');
  }
  final total = weights.fold<double>(0, (a, b) => a + b);
  if (total <= 0) throw ArgumentError('Укажите положительный КТУ');
  final units = (quantity * 1000).round();
  final raw = weights.map((w) => units * w / total).toList();
  final allocated = raw.map((v) => v.floor()).toList();
  final order = List<int>.generate(weights.length, (i) => i)
    ..sort((a, b) {
      final comparison = (raw[b] - allocated[b]).compareTo(
        raw[a] - allocated[a],
      );
      return comparison == 0 ? a.compareTo(b) : comparison;
    });
  var remainder = units - allocated.fold<int>(0, (a, b) => a + b);
  for (final index in order) {
    if (remainder-- <= 0) break;
    allocated[index]++;
  }
  return allocated.map((v) => v / 1000).toList();
}
