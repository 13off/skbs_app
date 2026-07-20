import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_assistant_result.dart';

class AiActionAuditRecord {
  final String id;
  final String status;

  const AiActionAuditRecord({required this.id, required this.status});
}

class AiActionAuditRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<AiActionAuditRecord> createProposed({
    required String companyId,
    required AiAssistantAction action,
  }) async {
    final response = await _client
        .from('ai_action_audit')
        .insert(<String, dynamic>{
          'company_id': companyId.trim(),
          'action_id': action.id,
          'action_type': action.type,
          'object_name': action.text('object_name').isEmpty
              ? null
              : action.text('object_name'),
          'proposal': <String, dynamic>{
            'title': action.title,
            'button_label': action.buttonLabel,
            'confirmation_required': action.confirmationRequired,
            'payload': action.payload,
          },
          'status': 'proposed',
        })
        .select('id, status')
        .single();

    return AiActionAuditRecord(
      id: response['id']?.toString() ?? '',
      status: response['status']?.toString() ?? 'proposed',
    );
  }

  static Future<void> markConfirmed(String auditId) {
    return _update(
      auditId,
      status: 'confirmed',
      confirmedAt: DateTime.now(),
    );
  }

  static Future<void> markCancelled(String auditId) {
    return _update(auditId, status: 'cancelled');
  }

  static Future<void> markCompleted(
    String auditId, {
    String? targetEntityType,
    String? targetEntityId,
  }) {
    return _update(
      auditId,
      status: 'completed',
      completedAt: DateTime.now(),
      targetEntityType: targetEntityType,
      targetEntityId: targetEntityId,
    );
  }

  static Future<void> markFailed(String auditId, Object error) {
    return _update(
      auditId,
      status: 'failed',
      completedAt: DateTime.now(),
      errorText: error.toString().replaceFirst('Exception: ', '').trim(),
    );
  }

  static Future<void> _update(
    String auditId, {
    required String status,
    DateTime? confirmedAt,
    DateTime? completedAt,
    String? targetEntityType,
    String? targetEntityId,
    String? errorText,
  }) async {
    final cleanId = auditId.trim();
    if (cleanId.isEmpty) return;
    final cleanError = errorText?.trim() ?? '';
    final limitedError = cleanError.length > 1000
        ? cleanError.substring(0, 1000)
        : cleanError;

    await _client
        .from('ai_action_audit')
        .update(<String, dynamic>{
          'status': status,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          if (confirmedAt != null)
            'confirmed_at': confirmedAt.toUtc().toIso8601String(),
          if (completedAt != null)
            'completed_at': completedAt.toUtc().toIso8601String(),
          if (targetEntityType?.trim().isNotEmpty == true)
            'target_entity_type': targetEntityType!.trim(),
          if (targetEntityId?.trim().isNotEmpty == true)
            'target_entity_id': targetEntityId!.trim(),
          if (limitedError.isNotEmpty) 'error_text': limitedError,
        })
        .eq('id', cleanId);
  }
}
