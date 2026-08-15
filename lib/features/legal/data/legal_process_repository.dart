import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/legal_models.dart';

const String legalCourtMatterType = 'court';

String legalMatterDisplayType(LegalMatter matter) {
  if (matter.matterType == legalCourtMatterType) return 'Судебное дело';
  return matter.typeTitle;
}

bool legalMatterIsCourt(LegalMatter matter) {
  if (matter.matterType == legalCourtMatterType) return true;
  final title = matter.title.trim().toLowerCase();
  return matter.matterType == LegalMatterType.dispute &&
      (title.startsWith('[суд]') || title.contains('судеб'));
}

class LegalMatterProcessDetails {
  final String matterId;
  final String courtCaseNumber;
  final String courtName;
  final String courtParties;
  final double? claimAmount;
  final String proceedingStage;
  final DateTime? nextHearingAt;
  final DateTime? outgoingSentAt;
  final DateTime? responseDueAt;

  const LegalMatterProcessDetails({
    required this.matterId,
    required this.courtCaseNumber,
    required this.courtName,
    required this.courtParties,
    required this.claimAmount,
    required this.proceedingStage,
    required this.nextHearingAt,
    required this.outgoingSentAt,
    required this.responseDueAt,
  });

  const LegalMatterProcessDetails.empty(String matterId)
      : this(
          matterId: matterId,
          courtCaseNumber: '',
          courtName: '',
          courtParties: '',
          claimAmount: null,
          proceedingStage: '',
          nextHearingAt: null,
          outgoingSentAt: null,
          responseDueAt: null,
        );

  factory LegalMatterProcessDetails.fromMap(Map<String, dynamic> map) {
    DateTime? date(dynamic value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
    }

    return LegalMatterProcessDetails(
      matterId: map['id']?.toString() ?? '',
      courtCaseNumber: map['court_case_number']?.toString() ?? '',
      courtName: map['court_name']?.toString() ?? '',
      courtParties: map['court_parties']?.toString() ?? '',
      claimAmount: double.tryParse(map['claim_amount']?.toString() ?? ''),
      proceedingStage: map['proceeding_stage']?.toString() ?? '',
      nextHearingAt: date(map['next_hearing_at']),
      outgoingSentAt: date(map['outgoing_sent_at']),
      responseDueAt: date(map['response_due_at']),
    );
  }

  bool get hasCourtData =>
      courtCaseNumber.isNotEmpty ||
      courtName.isNotEmpty ||
      courtParties.isNotEmpty ||
      proceedingStage.isNotEmpty ||
      nextHearingAt != null;

  bool get hasClaimData =>
      outgoingSentAt != null ||
      responseDueAt != null ||
      claimAmount != null ||
      proceedingStage.isNotEmpty;

  bool get isResponseOverdue =>
      responseDueAt != null && responseDueAt!.isBefore(DateTime.now());
}

abstract final class LegalProcessRepository {
  static SupabaseClient get _client => Supabase.instance.client;

  static const _columns =
      'id, court_case_number, court_name, court_parties, claim_amount, '
      'proceeding_stage, next_hearing_at, outgoing_sent_at, response_due_at';

  static Future<LegalMatterProcessDetails> fetchDetails(String matterId) async {
    final row = await _client
        .from('legal_matters')
        .select(_columns)
        .eq('id', matterId)
        .maybeSingle();
    if (row == null) return LegalMatterProcessDetails.empty(matterId);
    return LegalMatterProcessDetails.fromMap(Map<String, dynamic>.from(row));
  }

  static Future<Map<String, LegalMatterProcessDetails>> fetchDetailsMap(
    Iterable<String> matterIds,
  ) async {
    final ids = matterIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const <String, LegalMatterProcessDetails>{};
    final rows = await _client
        .from('legal_matters')
        .select(_columns)
        .inFilter('id', ids);
    return <String, LegalMatterProcessDetails>{
      for (final value in rows)
        if ((value['id']?.toString() ?? '').isNotEmpty)
          value['id'].toString(): LegalMatterProcessDetails.fromMap(
            Map<String, dynamic>.from(value),
          ),
    };
  }

  static Future<void> saveDetails({
    required String matterId,
    String courtCaseNumber = '',
    String courtName = '',
    String courtParties = '',
    double? claimAmount,
    String proceedingStage = '',
    DateTime? nextHearingAt,
    DateTime? outgoingSentAt,
    DateTime? responseDueAt,
  }) async {
    await _client
        .from('legal_matters')
        .update(<String, dynamic>{
          'court_case_number': courtCaseNumber.trim(),
          'court_name': courtName.trim(),
          'court_parties': courtParties.trim(),
          'claim_amount': claimAmount,
          'proceeding_stage': proceedingStage.trim(),
          'next_hearing_at': nextHearingAt?.toUtc().toIso8601String(),
          'outgoing_sent_at': outgoingSentAt?.toUtc().toIso8601String(),
          'response_due_at': responseDueAt?.toUtc().toIso8601String(),
          'updated_by': _client.auth.currentUser?.id,
        })
        .eq('id', matterId);
  }
}
