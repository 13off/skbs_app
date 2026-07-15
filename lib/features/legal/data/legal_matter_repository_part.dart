part of 'legal_repository.dart';

abstract final class _LegalMatters {
  static Future<List<LegalMatter>> fetchMatters({
    String search = '',
    String? status,
    bool attentionOnly = false,
  }) async {
    final values = await Future.wait<dynamic>([
      _client
          .from('legal_matters')
          .select(
            'id, matter_type, title, description, risk_level, status, due_at, responsible_user_id, employee_id, object_id, counterparty_id, document_id, required_actions, result, requires_foreman_action, requires_manager_decision, manager_question, decision_status, decision_comment, created_at, updated_at, employees(fio), objects(name), legal_counterparties(name)',
          )
          .order('updated_at', ascending: false),
      _LegalDirectories.responsibleNames(),
    ]);
    final responsibleNames = values[1] as Map<String, String>;
    var matters = (values[0] as List<dynamic>).map<LegalMatter>((value) {
      final row = _map(value);
      final responsibleId = row['responsible_user_id']?.toString() ?? '';
      return LegalMatter.fromMap(
        row,
        responsibleName: responsibleNames[responsibleId] ?? '',
      );
    }).toList();

    final cleanStatus = status?.trim() ?? '';
    if (cleanStatus.isNotEmpty) {
      matters = matters.where((item) => item.status == cleanStatus).toList();
    }
    if (attentionOnly) {
      matters = matters
          .where((item) => item.isOverdue || item.isHighRisk || item.needsManager)
          .toList();
    }
    final query = search.trim().toLowerCase();
    if (query.isNotEmpty) {
      matters = matters.where((item) {
        return item.title.toLowerCase().contains(query) ||
            item.description.toLowerCase().contains(query) ||
            item.employeeName.toLowerCase().contains(query) ||
            item.objectName.toLowerCase().contains(query) ||
            item.counterpartyName.toLowerCase().contains(query);
      }).toList();
    }
    return matters;
  }

  static Future<LegalMatter> fetchMatter(String id) async {
    final matters = await fetchMatters();
    return matters.firstWhere(
      (item) => item.id == id,
      orElse: () => throw Exception('Юридический вопрос не найден'),
    );
  }

  static Future<LegalMatter> saveMatter({
    String? id,
    required String matterType,
    required String title,
    required String description,
    required String riskLevel,
    required String status,
    DateTime? dueAt,
    String? responsibleUserId,
    String? employeeId,
    String? objectId,
    String? counterpartyId,
    String? documentId,
    required String requiredActions,
    required String result,
    required bool requiresForemanAction,
    required bool requiresManagerDecision,
    required String managerQuestion,
    required String decisionStatus,
    required String decisionComment,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final payload = <String, dynamic>{
      'matter_type': matterType,
      'title': title.trim(),
      'description': description.trim(),
      'risk_level': riskLevel,
      'status': status,
      'due_at': _optionalDateTime(dueAt),
      'responsible_user_id': _clean(responsibleUserId).isEmpty
          ? null
          : responsibleUserId,
      'employee_id': _clean(employeeId).isEmpty ? null : employeeId,
      'object_id': _clean(objectId).isEmpty ? null : objectId,
      'counterparty_id': _clean(counterpartyId).isEmpty
          ? null
          : counterpartyId,
      'document_id': _clean(documentId).isEmpty ? null : documentId,
      'required_actions': requiredActions.trim(),
      'result': result.trim(),
      'requires_foreman_action': requiresForemanAction,
      'requires_manager_decision': requiresManagerDecision,
      'manager_question': managerQuestion.trim(),
      'decision_status': requiresManagerDecision
          ? (decisionStatus == 'none' ? 'pending' : decisionStatus)
          : 'none',
      'decision_comment': decisionComment.trim(),
      'updated_by': userId,
    };

    final String matterId;
    if (_clean(id).isEmpty) {
      payload['created_by'] = userId;
      final row = await _client
          .from('legal_matters')
          .insert(payload)
          .select('id')
          .single();
      matterId = row['id']?.toString() ?? '';
    } else {
      await _client.from('legal_matters').update(payload).eq('id', id!);
      matterId = id;
    }

    _notifyLegalChanged('legal_matters', entityId: matterId);

    if (requiresManagerDecision) {
      unawaited(
        NotificationRepository.add(
          title: 'Требуется решение руководителя',
          body: title.trim(),
          entityType: 'legal_manager_decision',
          entityId: matterId,
          targetRole: 'admin',
          requiresAction: true,
          dueAt: dueAt,
          priority: riskLevel == 'critical' ? 'critical' : 'high',
        ),
      );
    } else if (requiresForemanAction && _clean(objectId).isNotEmpty) {
      final objects = await _LegalDirectories.fetchObjectDirectory();
      final objectName = objects
          .where((item) => item.id == objectId)
          .map((item) => item.title)
          .firstOrNull;
      unawaited(
        NotificationRepository.add(
          title: 'Новый юридический запрос',
          body: title.trim(),
          objectName: objectName,
          entityType: 'legal_matter',
          entityId: matterId,
          targetRole: 'foreman',
          requiresAction: true,
          dueAt: dueAt,
          priority: riskLevel == 'critical' ? 'critical' : 'normal',
        ),
      );
    }

    return fetchMatter(matterId);
  }

  static Future<void> decideMatter({
    required String matterId,
    required bool approved,
    required String comment,
  }) async {
    await _client
        .from('legal_matters')
        .update(<String, dynamic>{
          'decision_status': approved ? 'approved' : 'rejected',
          'decision_comment': comment.trim(),
        })
        .eq('id', matterId);
    _notifyLegalChanged('legal_matters', entityId: matterId);
  }
}
