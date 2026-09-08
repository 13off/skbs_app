import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/estimator_manual_volume.dart';

abstract final class EstimatorManualVolumeRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static const String _fields =
      'id, object_name, work, unit, quantity, work_date, reason_code, '
      'reason_comment, created_by_name, created_at, voided_at, '
      'voided_by_name, void_reason';

  static Future<List<EstimatorManualVolume>> fetchAll() async {
    final rows = await _client
        .from('estimator_manual_volumes')
        .select(_fields)
        .order('work_date', ascending: false)
        .order('created_at', ascending: false);
    return rows
        .map<EstimatorManualVolume>(
          (row) => EstimatorManualVolume.fromMap(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList(growable: false);
  }

  static Future<void> create({
    required String objectName,
    required String work,
    required String unit,
    required double quantity,
    required DateTime workDate,
    required String reasonCode,
    required String reasonComment,
  }) async {
    final date = DateTime(workDate.year, workDate.month, workDate.day);
    final dateText =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    await _client.rpc(
      'add_estimator_manual_volume',
      params: <String, dynamic>{
        'p_object_name': objectName.trim(),
        'p_work': work.trim(),
        'p_unit': unit.trim(),
        'p_quantity': quantity,
        'p_work_date': dateText,
        'p_reason_code': reasonCode.trim(),
        'p_reason_comment': reasonComment.trim(),
      },
    );
  }

  static Future<void> voidRecord({
    required String id,
    required String reason,
  }) async {
    await _client.rpc(
      'void_estimator_manual_volume',
      params: <String, dynamic>{
        'p_id': id.trim(),
        'p_reason': reason.trim(),
      },
    );
  }
}
