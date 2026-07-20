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
        })
        .select('id, status')
        .single();

    return AiActionAuditRecord(
      id: response['id']?.toString() ?? '',
      status: response['status']?.toString() ?? 'proposed',
    );
  }

  static Future<void> markConfirmed(String auditId) {
    return _transition(auditId, status: 'confirmed');
  }

  static Future<void> markCancelled(String auditId) {
    return _transition(auditId, status: 'cancelled');
  }

  static Future<void> markCompleted(
    String auditId, {
    String? targetEntityType,
    String? targetEntityId,
  }) {
    return _transition(
      auditId,
      status: 'completed',
      targetEntityType: targetEntityType,
      targetEntityId: targetEntityId,
    );
  }

  static Future<void> markFailed(String auditId, Object error) {
    final cleanError = error.toString().replaceFirst('Exception: ', '').trim();
    return _transition(
      auditId,
      status: 'failed',
      errorText: cleanError.length > 1000
          ? cleanError.substring(0, 1000)
          : cleanError,
    );
  }

  static Future<void> _transition(
    String auditId, {
    required String status,
    String? targetEntityType,
    String? targetEntityId,
    String? errorText,
  }) async {
    final cleanId = auditId.trim();
    if (cleanId.isEmpty) return;

    await _client.rpc<dynamic>(
      'transition_ai_action_audit',
      params: <String, dynamic>{
        'p_audit_id': cleanId,
        'p_status': status,
        'p_target_entity_type': targetEntityType?.trim(),
        'p_target_entity_id': targetEntityId?.trim(),
        'p_error_text': errorText?.trim(),
      },
    );
  }
}
