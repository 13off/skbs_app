import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/estimator_period_closing.dart';

abstract final class EstimatorClosingRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<List<EstimatorPeriodClosing>> fetchClosings({
    List<String>? statuses,
  }) async {
    var query = _client.from('estimator_period_closings').select();
    final cleanStatuses = statuses
        ?.map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final rows = cleanStatuses != null && cleanStatuses.isNotEmpty
        ? await query.inFilter('status', cleanStatuses).order('period_year', ascending: false).order('period_month', ascending: false)
        : await query.order('period_year', ascending: false).order('period_month', ascending: false);
    return rows
        .map<EstimatorPeriodClosing>((row) => EstimatorPeriodClosing.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  static Future<List<EstimatorClosingItem>> fetchItems(String closingId) async {
    final rows = await _client
        .from('estimator_period_closing_items')
        .select()
        .eq('closing_id', closingId)
        .order('work_date')
        .order('work');
    return rows.map<EstimatorClosingItem>((row) => EstimatorClosingItem.fromMap(Map<String, dynamic>.from(row))).toList(growable: false);
  }

  static Future<List<EstimatorClosingReview>> fetchReviews(String closingId) async {
    final rows = await _client
        .from('estimator_period_closing_reviews')
        .select()
        .eq('closing_id', closingId)
        .order('reviewed_at');
    return rows.map<EstimatorClosingReview>((row) => EstimatorClosingReview.fromMap(Map<String, dynamic>.from(row))).toList(growable: false);
  }

  static Future<List<EstimatorClosingEarning>> fetchEarnings(String closingId) async {
    final rows = await _client
        .from('estimator_closing_earnings')
        .select()
        .eq('closing_id', closingId)
        .order('employee_name');
    return rows.map<EstimatorClosingEarning>((row) => EstimatorClosingEarning.fromMap(Map<String, dynamic>.from(row))).toList(growable: false);
  }

  static Future<List<EstimatorClosingEarningIssue>> fetchEarningIssues(String closingId) async {
    final rows = await _client
        .from('estimator_closing_earning_issues')
        .select('issue_code, message')
        .eq('closing_id', closingId)
        .order('created_at');
    return rows.map<EstimatorClosingEarningIssue>((row) => EstimatorClosingEarningIssue.fromMap(Map<String, dynamic>.from(row))).toList(growable: false);
  }

  static Future<String> createOrRefresh({
    required String objectId,
    required int year,
    required int month,
  }) async {
    final value = await _client.rpc('create_or_refresh_estimator_period_closing', params: <String, dynamic>{
      'p_object_id': objectId,
      'p_period_year': year,
      'p_period_month': month,
    });
    return value?.toString() ?? '';
  }

  static Future<void> submit(String closingId) async {
    await _client.rpc('submit_estimator_period_closing', params: <String, dynamic>{'p_closing_id': closingId});
  }

  static Future<void> review({
    required String closingId,
    required String decision,
    String comment = '',
  }) async {
    await _client.rpc('review_estimator_period_closing', params: <String, dynamic>{
      'p_closing_id': closingId,
      'p_decision': decision,
      'p_comment': comment.trim(),
    });
  }

  static Future<void> markSent(String closingId) async {
    await _client.rpc('mark_estimator_period_closing_sent', params: <String, dynamic>{'p_closing_id': closingId});
  }

  static Future<void> markPaid(String closingId) async {
    await _client.rpc('mark_estimator_period_closing_paid', params: <String, dynamic>{'p_closing_id': closingId});
  }

  static Future<List<EstimatorPieceRate>> fetchRates({bool includeInactive = false}) async {
    final rows = includeInactive
        ? await _client.from('estimator_piece_rates').select().order('created_at', ascending: false)
        : await _client.from('estimator_piece_rates').select().eq('is_active', true).order('created_at', ascending: false);
    return rows.map<EstimatorPieceRate>((row) => EstimatorPieceRate.fromMap(Map<String, dynamic>.from(row))).toList(growable: false);
  }

  static Future<String> upsertRate({
    required String objectId,
    required String work,
    required String unit,
    required double rateAmount,
    required DateTime validFrom,
    DateTime? validTo,
  }) async {
    final value = await _client.rpc('upsert_estimator_piece_rate', params: <String, dynamic>{
      'p_object_id': objectId,
      'p_work': work.trim(),
      'p_unit': unit.trim(),
      'p_rate_amount': rateAmount,
      'p_valid_from': _date(validFrom),
      'p_valid_to': validTo == null ? null : _date(validTo),
    });
    return value?.toString() ?? '';
  }

  static Future<void> deactivateRate(String rateId) async {
    await _client.rpc('deactivate_estimator_piece_rate', params: <String, dynamic>{'p_rate_id': rateId});
  }

  static String _date(DateTime value) {
    final local = DateTime(value.year, value.month, value.day);
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}
