class RecruitmentApplication {
  final String id;
  final String companyId;
  final String source;
  final String sourceUserId;
  final String sourceChatId;
  final String fullName;
  final String phone;
  final String citizenship;
  final String vacancyId;
  final String vacancy;
  final String objectId;
  final String objectName;
  final String experience;
  final DateTime? departureDate;
  final String status;
  final String comment;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecruitmentApplication({
    required this.id,
    required this.companyId,
    required this.source,
    required this.sourceUserId,
    required this.sourceChatId,
    required this.fullName,
    required this.phone,
    required this.citizenship,
    required this.vacancyId,
    required this.vacancy,
    required this.objectId,
    required this.objectName,
    required this.experience,
    required this.departureDate,
    required this.status,
    required this.comment,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isArchived => archivedAt != null;

  String get sourceTitle {
    switch (source) {
      case 'telegram':
        return 'Telegram';
      case 'max':
        return 'MAX';
      default:
        return 'Вручную';
    }
  }

  String get statusTitle => recruitmentStatusTitle(status);
  String get stage => recruitmentStageKey(status);

  factory RecruitmentApplication.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value, {required DateTime fallback}) {
      return DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? fallback;
    }

    DateTime? optionalDate(dynamic value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
    }

    Map<String, dynamic> nested(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return const <String, dynamic>{};
    }

    final createdAt = parseDate(map['created_at'], fallback: DateTime.now());
    final object = nested(map['objects']);
    final vacancyRow = nested(map['recruitment_vacancies']);
    final positionTitle = map['position_title']?.toString().trim() ?? '';
    final vacancyTitle = vacancyRow['title']?.toString().trim() ?? '';

    return RecruitmentApplication(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      source: map['source']?.toString() ?? 'telegram',
      sourceUserId: map['external_user_id']?.toString() ?? '',
      sourceChatId: map['external_chat_id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      citizenship: map['citizenship']?.toString() ?? '',
      vacancyId: map['vacancy_id']?.toString() ?? '',
      vacancy: positionTitle.isNotEmpty ? positionTitle : vacancyTitle,
      objectId: map['object_id']?.toString() ?? '',
      objectName: object['name']?.toString() ?? '',
      experience: map['experience_text']?.toString() ?? '',
      departureDate: optionalDate(map['ready_date']),
      status: map['status']?.toString() ?? 'new',
      comment: map['hr_comment']?.toString() ?? '',
      archivedAt: optionalDate(map['archived_at']),
      createdAt: createdAt,
      updatedAt: parseDate(map['updated_at'], fallback: createdAt),
    );
  }
}

class RecruitmentObjectOption {
  final String id;
  final String name;

  const RecruitmentObjectOption({required this.id, required this.name});
}

class RecruitmentVacancyOption {
  final String id;
  final String objectId;
  final String title;

  const RecruitmentVacancyOption({
    required this.id,
    required this.objectId,
    required this.title,
  });
}

const List<String> recruitmentStatuses = <String>[
  'draft',
  'new',
  'contacted',
  'waiting_documents',
  'review',
  'medical',
  'approved',
  'ticket_request',
  'in_transit',
  'arrived',
  'hired',
  'reserve',
  'rejected',
];

const List<String> recruitmentStages = <String>[
  'new',
  'documents',
  'problems',
  'ready',
  'tickets',
  'completed',
  'reserve',
  'rejected',
];

String recruitmentStatusTitle(String status) {
  switch (status) {
    case 'draft':
      return 'Черновик бота';
    case 'contacted':
      return 'Связались';
    case 'waiting_documents':
      return 'Ждём документы';
    case 'review':
      return 'Проверка / косяки';
    case 'medical':
      return 'Медкомиссия';
    case 'approved':
      return 'Готов к вылету';
    case 'ticket_request':
      return 'Нужны билеты';
    case 'in_transit':
      return 'В пути';
    case 'arrived':
      return 'Прибыл';
    case 'hired':
      return 'Оформлен';
    case 'reserve':
      return 'Резерв';
    case 'rejected':
      return 'Отказ';
    default:
      return 'Новый';
  }
}

String recruitmentStageKey(String status) {
  switch (status) {
    case 'waiting_documents':
    case 'medical':
      return 'documents';
    case 'review':
      return 'problems';
    case 'approved':
      return 'ready';
    case 'ticket_request':
    case 'in_transit':
      return 'tickets';
    case 'arrived':
    case 'hired':
      return 'completed';
    case 'reserve':
      return 'reserve';
    case 'rejected':
      return 'rejected';
    default:
      return 'new';
  }
}

String recruitmentStageTitle(String stage) {
  switch (stage) {
    case 'documents':
      return 'Ждём документы';
    case 'problems':
      return 'Косяки';
    case 'ready':
      return 'Готовы к вылету';
    case 'tickets':
      return 'Нужны билеты';
    case 'completed':
      return 'Оформлены';
    case 'reserve':
      return 'Резерв';
    case 'rejected':
      return 'Отказ';
    default:
      return 'Новые';
  }
}

class RecruitmentDashboardData {
  final List<RecruitmentApplication> applications;
  final Map<String, int> counts;

  const RecruitmentDashboardData({
    required this.applications,
    required this.counts,
  });

  int count(String stage) => counts[stage] ?? 0;
  int get total => applications.length;
}
