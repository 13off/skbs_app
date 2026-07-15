class LegalDirectoryItem {
  final String id;
  final String title;
  final String subtitle;

  const LegalDirectoryItem({
    required this.id,
    required this.title,
    this.subtitle = '',
  });
}

class LegalCounterparty {
  final String id;
  final String name;
  final String category;
  final String inn;
  final String kpp;
  final String ogrn;
  final String contactName;
  final String phone;
  final String email;
  final String comment;
  final String status;

  const LegalCounterparty({
    required this.id,
    required this.name,
    required this.category,
    required this.inn,
    required this.kpp,
    required this.ogrn,
    required this.contactName,
    required this.phone,
    required this.email,
    required this.comment,
    required this.status,
  });

  factory LegalCounterparty.fromMap(Map<String, dynamic> map) {
    return LegalCounterparty(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      category: map['category']?.toString() ?? 'other',
      inn: map['inn']?.toString() ?? '',
      kpp: map['kpp']?.toString() ?? '',
      ogrn: map['ogrn']?.toString() ?? '',
      contactName: map['contact_name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      comment: map['comment']?.toString() ?? '',
      status: map['status']?.toString() ?? 'active',
    );
  }
}

class LegalDocument {
  final String id;
  final String title;
  final String documentType;
  final String documentNumber;
  final String status;
  final DateTime createdOn;
  final DateTime? signedOn;
  final DateTime? validFrom;
  final DateTime? expiresOn;
  final String responsibleUserId;
  final String responsibleName;
  final String employeeId;
  final String employeeName;
  final String objectId;
  final String objectName;
  final String counterpartyId;
  final String counterpartyName;
  final String taskId;
  final String legalMatterId;
  final String comment;
  final String nextAction;
  final DateTime? nextActionDueAt;
  final bool requiresForemanAction;
  final bool requiresManagerApproval;
  final String approvalStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LegalDocument({
    required this.id,
    required this.title,
    required this.documentType,
    required this.documentNumber,
    required this.status,
    required this.createdOn,
    required this.signedOn,
    required this.validFrom,
    required this.expiresOn,
    required this.responsibleUserId,
    required this.responsibleName,
    required this.employeeId,
    required this.employeeName,
    required this.objectId,
    required this.objectName,
    required this.counterpartyId,
    required this.counterpartyName,
    required this.taskId,
    required this.legalMatterId,
    required this.comment,
    required this.nextAction,
    required this.nextActionDueAt,
    required this.requiresForemanAction,
    required this.requiresManagerApproval,
    required this.approvalStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  static DateTime _date(dynamic value, {DateTime? fallback}) {
    return DateTime.tryParse(value?.toString() ?? '') ??
        fallback ??
        DateTime.now();
  }

  static DateTime? _optionalDate(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
  }

  static Map<String, dynamic> _nested(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  factory LegalDocument.fromMap(
    Map<String, dynamic> map, {
    String responsibleName = '',
  }) {
    final employee = _nested(map['employees']);
    final object = _nested(map['objects']);
    final counterparty = _nested(map['legal_counterparties']);

    return LegalDocument(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      documentType: map['document_type']?.toString() ?? '',
      documentNumber: map['document_number']?.toString() ?? '',
      status: map['status']?.toString() ?? 'draft',
      createdOn: _date(map['created_on']),
      signedOn: _optionalDate(map['signed_on']),
      validFrom: _optionalDate(map['valid_from']),
      expiresOn: _optionalDate(map['expires_on']),
      responsibleUserId: map['responsible_user_id']?.toString() ?? '',
      responsibleName: responsibleName,
      employeeId: map['employee_id']?.toString() ?? '',
      employeeName: employee['fio']?.toString() ?? '',
      objectId: map['object_id']?.toString() ?? '',
      objectName: object['name']?.toString() ?? '',
      counterpartyId: map['counterparty_id']?.toString() ?? '',
      counterpartyName: counterparty['name']?.toString() ?? '',
      taskId: map['task_id']?.toString() ?? '',
      legalMatterId: map['legal_matter_id']?.toString() ?? '',
      comment: map['comment']?.toString() ?? '',
      nextAction: map['next_action']?.toString() ?? '',
      nextActionDueAt: _optionalDate(map['next_action_due_at']),
      requiresForemanAction: map['requires_foreman_action'] == true,
      requiresManagerApproval: map['requires_manager_approval'] == true,
      approvalStatus: map['approval_status']?.toString() ?? 'none',
      createdAt: _optionalDate(map['created_at']),
      updatedAt: _optionalDate(map['updated_at']),
    );
  }

  String get statusTitle => LegalDocumentStatus.title(status);

  String get expiryTitle {
    final expiry = expiresOn;
    if (expiry == null) return 'Без срока';
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final target = DateTime(expiry.year, expiry.month, expiry.day);
    final days = target.difference(day).inDays;
    if (days < 0) return 'Просрочен';
    if (days == 0) return 'Истекает сегодня';
    if (days <= 30) return 'Истекает через $days дн.';
    return 'Срок в норме';
  }

  bool get isExpired {
    final expiry = expiresOn;
    if (expiry == null) return false;
    final now = DateTime.now();
    return expiry.isBefore(DateTime(now.year, now.month, now.day));
  }

  bool get isExpiringSoon {
    final expiry = expiresOn;
    if (expiry == null || isExpired) return false;
    return expiry.difference(DateTime.now()).inDays <= 30;
  }

  bool get isActionOverdue {
    final due = nextActionDueAt;
    return due != null && due.isBefore(DateTime.now());
  }

  bool get needsAttention {
    return status == LegalDocumentStatus.awaitingSignature ||
        status == LegalDocumentStatus.needsCorrection ||
        approvalStatus == 'pending' ||
        isExpired ||
        isExpiringSoon ||
        isActionOverdue;
  }
}

class LegalMatter {
  final String id;
  final String matterType;
  final String title;
  final String description;
  final String riskLevel;
  final String status;
  final DateTime? dueAt;
  final String responsibleUserId;
  final String responsibleName;
  final String employeeId;
  final String employeeName;
  final String objectId;
  final String objectName;
  final String counterpartyId;
  final String counterpartyName;
  final String documentId;
  final String requiredActions;
  final String result;
  final bool requiresForemanAction;
  final bool requiresManagerDecision;
  final String managerQuestion;
  final String decisionStatus;
  final String decisionComment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LegalMatter({
    required this.id,
    required this.matterType,
    required this.title,
    required this.description,
    required this.riskLevel,
    required this.status,
    required this.dueAt,
    required this.responsibleUserId,
    required this.responsibleName,
    required this.employeeId,
    required this.employeeName,
    required this.objectId,
    required this.objectName,
    required this.counterpartyId,
    required this.counterpartyName,
    required this.documentId,
    required this.requiredActions,
    required this.result,
    required this.requiresForemanAction,
    required this.requiresManagerDecision,
    required this.managerQuestion,
    required this.decisionStatus,
    required this.decisionComment,
    required this.createdAt,
    required this.updatedAt,
  });

  static DateTime? _date(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
  }

  static Map<String, dynamic> _nested(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  factory LegalMatter.fromMap(
    Map<String, dynamic> map, {
    String responsibleName = '',
  }) {
    final employee = _nested(map['employees']);
    final object = _nested(map['objects']);
    final counterparty = _nested(map['legal_counterparties']);

    return LegalMatter(
      id: map['id']?.toString() ?? '',
      matterType: map['matter_type']?.toString() ?? 'task',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      riskLevel: map['risk_level']?.toString() ?? 'medium',
      status: map['status']?.toString() ?? 'open',
      dueAt: _date(map['due_at']),
      responsibleUserId: map['responsible_user_id']?.toString() ?? '',
      responsibleName: responsibleName,
      employeeId: map['employee_id']?.toString() ?? '',
      employeeName: employee['fio']?.toString() ?? '',
      objectId: map['object_id']?.toString() ?? '',
      objectName: object['name']?.toString() ?? '',
      counterpartyId: map['counterparty_id']?.toString() ?? '',
      counterpartyName: counterparty['name']?.toString() ?? '',
      documentId: map['document_id']?.toString() ?? '',
      requiredActions: map['required_actions']?.toString() ?? '',
      result: map['result']?.toString() ?? '',
      requiresForemanAction: map['requires_foreman_action'] == true,
      requiresManagerDecision: map['requires_manager_decision'] == true,
      managerQuestion: map['manager_question']?.toString() ?? '',
      decisionStatus: map['decision_status']?.toString() ?? 'none',
      decisionComment: map['decision_comment']?.toString() ?? '',
      createdAt: _date(map['created_at']),
      updatedAt: _date(map['updated_at']),
    );
  }

  String get typeTitle => LegalMatterType.title(matterType);
  String get statusTitle => LegalMatterStatus.title(status);
  String get riskTitle => LegalRiskLevel.title(riskLevel);

  bool get isOverdue {
    final due = dueAt;
    return due != null &&
        due.isBefore(DateTime.now()) &&
        status != 'resolved' &&
        status != 'closed';
  }

  bool get isHighRisk => riskLevel == 'high' || riskLevel == 'critical';
  bool get needsManager =>
      requiresManagerDecision && decisionStatus == 'pending';
}

class LegalFile {
  final String id;
  final String originalName;
  final String bucketName;
  final String storagePath;
  final String mimeType;
  final int sizeBytes;
  final DateTime? createdAt;

  const LegalFile({
    required this.id,
    required this.originalName,
    required this.bucketName,
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
  });

  factory LegalFile.fromMap(Map<String, dynamic> map) {
    return LegalFile(
      id: map['id']?.toString() ?? '',
      originalName: map['original_name']?.toString() ?? 'Файл',
      bucketName: map['bucket_name']?.toString() ?? 'legal-files',
      storagePath: map['storage_path']?.toString() ?? '',
      mimeType: map['mime_type']?.toString() ?? '',
      sizeBytes: int.tryParse(map['size_bytes']?.toString() ?? '') ?? 0,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal(),
    );
  }
}

class LegalDashboardData {
  final List<LegalDocument> documents;
  final List<LegalMatter> matters;
  final LegalWeeklyReport? latestReport;

  const LegalDashboardData({
    required this.documents,
    required this.matters,
    required this.latestReport,
  });

  List<LegalDocument> get awaitingSignature => documents
      .where((item) => item.status == LegalDocumentStatus.awaitingSignature)
      .toList();

  List<LegalDocument> get expiring => documents
      .where((item) => item.isExpired || item.isExpiringSoon)
      .toList();

  List<LegalDocument> get pendingApproval => documents
      .where((item) => item.approvalStatus == 'pending')
      .toList();

  List<LegalMatter> get overdueMatters =>
      matters.where((item) => item.isOverdue).toList();

  List<LegalMatter> get highRisks =>
      matters.where((item) => item.isHighRisk && item.status != 'closed').toList();

  List<LegalMatter> get managerDecisions =>
      matters.where((item) => item.needsManager).toList();
}

class LegalWeeklyReport {
  final String id;
  final DateTime weekStart;
  final DateTime weekEnd;
  final String status;
  final Map<String, dynamic> autoDraft;
  final String authorComment;
  final String nextWeekPlan;
  final String managerDecisions;
  final DateTime? submittedAt;

  const LegalWeeklyReport({
    required this.id,
    required this.weekStart,
    required this.weekEnd,
    required this.status,
    required this.autoDraft,
    required this.authorComment,
    required this.nextWeekPlan,
    required this.managerDecisions,
    required this.submittedAt,
  });

  factory LegalWeeklyReport.fromMap(Map<String, dynamic> map) {
    final draft = map['auto_draft'];
    return LegalWeeklyReport(
      id: map['id']?.toString() ?? '',
      weekStart:
          DateTime.tryParse(map['week_start']?.toString() ?? '') ?? DateTime.now(),
      weekEnd:
          DateTime.tryParse(map['week_end']?.toString() ?? '') ?? DateTime.now(),
      status: map['status']?.toString() ?? 'draft',
      autoDraft: draft is Map
          ? Map<String, dynamic>.from(draft)
          : const <String, dynamic>{},
      authorComment: map['author_comment']?.toString() ?? '',
      nextWeekPlan: map['next_week_plan']?.toString() ?? '',
      managerDecisions: map['manager_decisions']?.toString() ?? '',
      submittedAt:
          DateTime.tryParse(map['submitted_at']?.toString() ?? '')?.toLocal(),
    );
  }
}

abstract final class LegalDocumentStatus {
  static const draft = 'draft';
  static const prepared = 'prepared';
  static const review = 'review';
  static const awaitingSignature = 'awaiting_signature';
  static const signed = 'signed';
  static const needsCorrection = 'needs_correction';
  static const terminated = 'terminated';
  static const archive = 'archive';

  static const values = <String>[
    draft,
    prepared,
    review,
    awaitingSignature,
    signed,
    needsCorrection,
    terminated,
    archive,
  ];

  static String title(String value) {
    switch (value) {
      case prepared:
        return 'Подготовлен';
      case review:
        return 'На согласовании';
      case awaitingSignature:
        return 'Ожидает подписи';
      case signed:
        return 'Подписан';
      case needsCorrection:
        return 'Требует исправления';
      case terminated:
        return 'Расторгнут';
      case archive:
        return 'Архив';
      default:
        return 'Черновик';
    }
  }
}

abstract final class LegalRiskLevel {
  static const low = 'low';
  static const medium = 'medium';
  static const high = 'high';
  static const critical = 'critical';
  static const values = <String>[low, medium, high, critical];

  static String title(String value) {
    switch (value) {
      case low:
        return 'Низкий';
      case high:
        return 'Высокий';
      case critical:
        return 'Критический';
      default:
        return 'Средний';
    }
  }
}

abstract final class LegalMatterStatus {
  static const open = 'open';
  static const inProgress = 'in_progress';
  static const waiting = 'waiting';
  static const resolved = 'resolved';
  static const closed = 'closed';
  static const values = <String>[open, inProgress, waiting, resolved, closed];

  static String title(String value) {
    switch (value) {
      case inProgress:
        return 'В работе';
      case waiting:
        return 'Ожидание';
      case resolved:
        return 'Решён';
      case closed:
        return 'Закрыт';
      default:
        return 'Открыт';
    }
  }
}

abstract final class LegalMatterType {
  static const task = 'task';
  static const claim = 'claim';
  static const violation = 'violation';
  static const dispute = 'dispute';
  static const penaltyRisk = 'penalty_risk';
  static const employeeRequest = 'employee_request';
  static const contractProblem = 'contract_problem';
  static const managerDecision = 'manager_decision';
  static const other = 'other';

  static const values = <String>[
    task,
    claim,
    violation,
    dispute,
    penaltyRisk,
    employeeRequest,
    contractProblem,
    managerDecision,
    other,
  ];

  static String title(String value) {
    switch (value) {
      case claim:
        return 'Претензия';
      case violation:
        return 'Нарушение';
      case dispute:
        return 'Спор';
      case penaltyRisk:
        return 'Штрафной риск';
      case employeeRequest:
        return 'Запрос сотрудника';
      case contractProblem:
        return 'Проблема с договором';
      case managerDecision:
        return 'Решение руководителя';
      case other:
        return 'Другое';
      default:
        return 'Юридическая задача';
    }
  }
}
