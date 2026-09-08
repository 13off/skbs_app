import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/estimator_closing_operations.dart';

abstract final class EstimatorClosingOperationsRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<List<EstimatorClosingPackageEntry>> fetchPackage(String closingId) async {
    final rows = await _client
        .from('estimator_closing_package_entries')
        .select()
        .eq('closing_id', closingId)
        .isFilter('voided_at', null)
        .order('created_at');
    return rows
        .map<EstimatorClosingPackageEntry>((row) => EstimatorClosingPackageEntry.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  static Future<String> addPackageEntry({
    required String closingId,
    required String kind,
    required String title,
    String documentNumber = '',
    DateTime? documentDate,
    String note = '',
  }) async {
    final value = await _client.rpc('add_estimator_closing_package_entry', params: <String, dynamic>{
      'p_closing_id': closingId,
      'p_kind': kind,
      'p_title': title.trim(),
      'p_document_number': documentNumber.trim(),
      'p_document_date': documentDate == null ? null : _date(documentDate),
      'p_note': note.trim(),
    });
    return value?.toString() ?? '';
  }

  static Future<void> verifyPackageEntry(String entryId, {String status = 'verified'}) async {
    await _client.rpc('verify_estimator_closing_package_entry', params: <String, dynamic>{
      'p_entry_id': entryId,
      'p_status': status,
    });
  }

  static Future<void> voidPackageEntry(String entryId, String reason) async {
    await _client.rpc('void_estimator_closing_package_entry', params: <String, dynamic>{
      'p_entry_id': entryId,
      'p_reason': reason.trim(),
    });
  }

  static Future<void> refreshPayouts(String closingId) async {
    await _client.rpc('refresh_estimator_closing_payout_lines', params: <String, dynamic>{'p_closing_id': closingId});
  }

  static Future<List<EstimatorClosingPayoutLine>> fetchPayouts(String closingId) async {
    final rows = await _client
        .from('estimator_closing_payout_lines')
        .select()
        .eq('closing_id', closingId)
        .order('employee_name');
    return rows
        .map<EstimatorClosingPayoutLine>((row) => EstimatorClosingPayoutLine.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  static Future<void> linkPayment({required String lineId, required String paymentId}) async {
    await _client.rpc('link_estimator_payout_payment', params: <String, dynamic>{
      'p_line_id': lineId,
      'p_payment_id': paymentId,
    });
  }

  static Future<void> unlinkPayment(String lineId) async {
    await _client.rpc('unlink_estimator_payout_payment', params: <String, dynamic>{'p_line_id': lineId});
  }

  static Future<EstimatorClosingDashboard> fetchDashboard({
    required int year,
    required int month,
    String? objectId,
  }) async {
    final value = await _client.rpc('get_estimator_closing_dashboard', params: <String, dynamic>{
      'p_year': year,
      'p_month': month,
      'p_object_id': objectId?.trim().isEmpty == true ? null : objectId,
    });
    return EstimatorClosingDashboard.fromMap(Map<String, dynamic>.from(value as Map));
  }

  static String _date(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
