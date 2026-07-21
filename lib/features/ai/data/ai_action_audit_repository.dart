import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_assistant_result.dart';

class AiActionAuditRecord {
  final String id;
  final String userId;
  final String actorName;
  final String actorEmail;
  final String actionId;
  final String actionType;
  final String objectName;
  final Map<String, dynamic> proposal;
  final String status;
  final String targetEntityType;
  final String targetEntityId;
  final String errorText;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final DateTime? completedAt;

  const AiActionAuditRecord({
    required this.id,
    this.userId = '',
    this.actorName = '',
    this.actorEmail = '',
    this.actionId = '',
    this.actionType = '',
    this.objectName = '',
    this.proposal = const <String, dynamic>{},
    required this.status,
    this.targetEntityType = '',
    this.targetEntityId = '',
    required this.errorText,
    required this.createdAt,
    this.confirmedAt,
    this.completedAt,
  });

  factory AiActionAuditRecord.created({
    required String id,
    required String status,
  }) {
    return AiActionAuditRecord(
      id: id,
      status: status,
      errorText: '',
      createdAt: DateTime.now(),
    );
  }

  factory AiActionAuditRecord.fromMap(
    Map<String, dynamic> map, {
    String actorName = '',
    String actorEmail = '',
  }) {
    return AiActionAuditRecord(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      actorName: actorName,
      actorEmail: actorEmail,
      actionId: map['action_id']?.toString() ?? '',
      actionType: map['action_type']?.toString() ?? '',
      objectName: map['object_name']?.toString() ?? '',
      proposal: map['proposal'] is Map
          ? Map<String, dynamic>.from(map['proposal'] as Map)
          : const <String, dynamic>{},
      status: map['status']?.toString() ?? 'proposed',
      targetEntityType: map['target_entity_type']?.toString() ?? '',
      targetEntityId: map['target_entity_id']?.toString() ?? '',
      errorText: map['error_text']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      confirmedAt: DateTime.tryParse(
        map['confirmed_at']?.toString() ?? '',
      ),
      completedAt: DateTime.tryParse(
        map['completed_at']?.toString() ?? '',
      ),
    );
  }

  String get title => proposal['title']?.toString().trim().isNotEmpty == true
      ? proposal['title'].toString().trim()
      : actionTypeTitle(actionType);

  Map<String, dynamic> get payload {
    final value = proposal['payload'];
    return value is Map
        ? Map<String, dynamic>.from(value)
        : const <String, dynamic>{};
  }

  String get actorLabel {
    if (actorName.trim().isNotEmpty) return actorName.trim();
    if (actorEmail.trim().isNotEmpty) return actorEmail.trim();
    if (userId.trim().isNotEmpty) return userId.trim();
    return 'Пользователь';
  }

  static String actionTypeTitle(String type) {
    return switch (type) {
      'create_task_draft' => 'Создание задачи',
      'prepare_document' => 'Подготовка документа',
      'prepare_timesheet_correction' => 'Корректировка табеля',
      'prepare_employee_update' => 'Изменение сотрудника',
      'create_reminder' => 'Создание напоминания',
      _ => type.isEmpty ? 'Действие ИИ' : type,
    };
  }
}

class AiActionAuditRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<List<AiActionAuditRecord>> fetchHistory({
    required String companyId,
    int limit = 200,
  }) async {
    final cleanCompanyId = companyId.trim();
    if (cleanCompanyId.isEmpty) return const <AiActionAuditRecord>[];

    final rows = await _client
        .from('ai_action_audit')
        .select(
          'id, user_id, action_id, action_type, object_name, proposal, status, '
          'target_entity_type, target_entity_id, error_text, created_at, '
          'confirmed_at, completed_at',
        )
        .eq('company_id', cleanCompanyId)
        .order('created_at', ascending: false)
        .limit(limit);

    final normalizedRows = rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    final userIds = normalizedRows
        .map((row) => row['user_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final actors = <String, ({String name, String email})>{};

    if (userIds.isNotEmpty) {
      try {
        final profileRows = await _client
            .from('user_profiles')
            .select('id, full_name, email')
            .inFilter('id', userIds);
        for (final raw in profileRows.whereType<Map>()) {
          final row = Map<String, dynamic>.from(raw);
          final id = row['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          actors[id] = (
            name: row['full_name']?.toString() ?? '',
            email: row['email']?.toString() ?? '',
          );
        }
      } catch (_) {
        // История остаётся доступной даже при более строгом RLS профилей.
      }
    }

    return normalizedRows.map((row) {
      final userId = row['user_id']?.toString() ?? '';
      final actor = actors[userId];
      return AiActionAuditRecord.fromMap(
        row,
        actorName: actor?.name ?? '',
        actorEmail: actor?.email ?? '',
      );
    }).toList(growable: false);
  }

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

    return AiActionAuditRecord.created(
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
