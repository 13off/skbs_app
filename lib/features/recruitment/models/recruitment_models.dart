class RecruitmentApplication {
  final String id;
  final String companyId;
  final String source;
  final String sourceUserId;
  final String sourceChatId;
  final String fullName;
  final String phone;
  final String citizenship;
  final String vacancy;
  final String objectName;
  final String experience;
  final DateTime? departureDate;
  final String status;
  final String comment;
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
    required this.vacancy,
    required this.objectName,
    required this.experience,
    required this.departureDate,
    required this.status,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

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

  factory RecruitmentApplication.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value, {required DateTime fallback}) {
      return DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? fallback;
    }

    DateTime? optionalDate(dynamic value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
    }

    final createdAt = parseDate(map['created_at'], fallback: DateTime.now());
    return RecruitmentApplication(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      source: map['source']?.toString() ?? 'manual',
      sourceUserId: map['source_user_id']?.toString() ?? '',
      sourceChatId: map['source_chat_id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      citizenship: map['citizenship']?.toString() ?? '',
      vacancy: map['vacancy']?.toString() ?? '',
      objectName: map['object_name']?.toString() ?? '',
      experience: map['experience']?.toString() ?? '',
      departureDate: optionalDate(map['departure_date']),
      status: map['status']?.toString() ?? 'new',
      comment: map['comment']?.toString() ?? '',
      createdAt: createdAt,
      updatedAt: parseDate(map['updated_at'], fallback: createdAt),
    );
  }
}

const List<String> recruitmentStatuses = <String>[
  'new',
  'documents',
  'problems',
  'ready',
  'tickets',
  'completed',
  'rejected',
];

String recruitmentStatusTitle(String status) {
  switch (status) {
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

  int count(String status) => counts[status] ?? 0;
  int get total => applications.length;
}
