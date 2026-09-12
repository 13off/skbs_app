import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkOrderRepository {
  static final _db = Supabase.instance.client;
  static String dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  static Future<Map<String, dynamic>?> plan(String taskId) => _db
      .from('task_work_plans').select().eq('task_id', taskId).maybeSingle();

  static Future<void> savePlan({
    required String taskId,
    required double? planned,
    required String unit,
  }) async {
    await _db.rpc('save_task_work_day', params: {
      'p_task_id': taskId,
      'p_planned': planned,
      'p_unit': unit,
      'p_date': dateKey(DateTime.now()),
      'p_quantity': null,
      'p_participants': const <Map<String, dynamic>>[],
    });
  }

  static Future<Map<String, dynamic>?> day(
    String taskId,
    DateTime date,
  ) => _db
      .from('task_work_days')
      .select()
      .eq('task_id', taskId)
      .eq('work_date', dateKey(date))
      .maybeSingle();

  static Future<List<Map<String, dynamic>>> days(String taskId) async =>
      await _db.from('task_work_days').select().eq('task_id', taskId)
          .order('work_date');

  static Future<void> save({required String taskId, required double? planned,
    required String unit, required DateTime date, required double? quantity,
    required List<Map<String, dynamic>> participants}) async {
    await _db.rpc('save_task_work_day', params: {
      'p_task_id': taskId, 'p_planned': planned, 'p_unit': unit,
      'p_date': dateKey(date), 'p_quantity': quantity,
      'p_participants': participants,
    });
  }

  static Future<void> deleteDay(String taskId, DateTime date) async {
    await _db.from('task_work_days').delete().eq('task_id', taskId)
        .eq('work_date', dateKey(date));
  }

  static Future<List<Map<String, dynamic>>> period(DateTime start,
      DateTime end, String? objectName) async {
    // Page explicitly: PostgREST's default row limit must not truncate a month.
    final result = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 500) {
      var query = _db.from('task_work_days')
          .select('*, tasks!inner(object_name, work, axes, status)')
          .gte('work_date', dateKey(start)).lte('work_date', dateKey(end));
      if (objectName != null && objectName.trim().isNotEmpty) {
        query = query.eq('tasks.object_name', objectName.trim());
      }
      final rows = await query.order('work_date').order('task_id')
          .range(offset, offset + 499);
      result.addAll(rows);
      if (rows.length < 500) break;
    }
    return result;
  }
}

/// Allocate thousandths with largest remainders, preserving the day's total.
List<double> allocateWorkQuantity(double quantity, List<double> weights) {
  if (!quantity.isFinite || quantity < 0 || weights.isEmpty ||
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
      final comparison = (raw[b] - allocated[b]).compareTo(raw[a] - allocated[a]);
      return comparison == 0 ? a.compareTo(b) : comparison;
    });
  var remainder = units - allocated.fold<int>(0, (a, b) => a + b);
  for (final index in order) {
    if (remainder-- <= 0) break;
    allocated[index]++;
  }
  return allocated.map((v) => v / 1000).toList();
}
