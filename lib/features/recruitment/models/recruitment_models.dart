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
  final String stageId;
  final String responsibleUserId;
  final String comment;
  final Map<String, dynamic> customValues;
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
    required this.stageId,
    this.responsibleUserId = '',
    required this.comment,
    required this.customValues,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isArchived => archivedAt != null;
  bool get canMessageInTelegram =>
      source == 'telegram' && sourceChatId.trim().isNotEmpty;

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

  dynamic customValue(String fieldId) => customValues[fieldId];

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
      stageId: map['stage_id']?.toString() ?? '',
      responsibleUserId: map['responsible_user_id']?.toString() ?? '',
      comment: map['hr_comment']?.toString() ?? '',
      customValues: nested(map['custom_values']),
      archivedAt: optionalDate(map['archived_at']),
      createdAt: createdAt,
      updatedAt: parseDate(map['updated_at'], fallback: createdAt),
    );
  }
}

class RecruitmentDocument {
  final String id;
  final String applicationId;
  final String documentType;
  final String storageBucket;
  final String storagePath;
  final String originalName;
  final String mimeType;
  final int? sizeBytes;
  final bool isTestCopy;
  final DateTime createdAt;

  const RecruitmentDocument({
    required this.id,
    required this.applicationId,
    required this.documentType,
    required this.storageBucket,
    required this.storagePath,
    required this.originalName,
    required this.mimeType,
    required this.sizeBytes,
    required this.isTestCopy,
    required this.createdAt,
  });

  bool get isStored =>
      storageBucket == 'recruitment-documents' &&
      storagePath.isNotEmpty &&
      !storagePath.startsWith('telegram://');

  String get title => recruitmentDocumentTitle(documentType);
  bool get isImage => mimeType.startsWith('image/');

  factory RecruitmentDocument.fromMap(Map<String, dynamic> map) {
    return RecruitmentDocument(
      id: map['id']?.toString() ?? '',
      applicationId: map['application_id']?.toString() ?? '',
      documentType: map['document_type']?.toString() ?? 'other',
      storageBucket: map['storage_bucket']?.toString() ?? '',
      storagePath: map['storage_path']?.toString() ?? '',
      originalName: map['original_name']?.toString() ?? '',
      mimeType: map['mime_type']?.toString() ?? 'application/octet-stream',
      sizeBytes: switch (map['size_bytes']) {
        int value => value,
        num value => value.toInt(),
        _ => int.tryParse(map['size_bytes']?.toString() ?? ''),
      },
      isTestCopy: map['is_test_copy'] == true,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

class RecruitmentMessage {
  final String id;
  final String applicationId;
  final String direction;
  final String text;
  final String storageBucket;
  final String storagePath;
  final String originalName;
  final String mimeType;
  final int? sizeBytes;
  final DateTime createdAt;

  const RecruitmentMessage({
    required this.id,
    required this.applicationId,
    required this.direction,
    required this.text,
    required this.storageBucket,
    required this.storagePath,
    required this.originalName,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
  });

  bool get isInbound => direction == 'inbound';
  bool get hasAttachment => storagePath.isNotEmpty;
  bool get isStoredAttachment =>
      storageBucket == 'recruitment-documents' &&
      storagePath.isNotEmpty &&
      !storagePath.startsWith('telegram://');

  factory RecruitmentMessage.fromMap(Map<String, dynamic> map) {
    return RecruitmentMessage(
      id: map['id']?.toString() ?? '',
      applicationId: map['application_id']?.toString() ?? '',
      direction: map['direction']?.toString() ?? 'system',
      text: map['message_text']?.toString() ?? '',
      storageBucket: map['storage_bucket']?.toString() ?? '',
      storagePath: map['storage_path']?.toString() ?? '',
      originalName: map['original_name']?.toString() ?? '',
      mimeType: map['mime_type']?.toString() ?? '',
      sizeBytes: switch (map['size_bytes']) {
        int value => value,
        num value => value.toInt(),
        _ => int.tryParse(map['size_bytes']?.toString() ?? ''),
      },
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

String recruitmentDocumentTitle(String type) {
  switch (type) {
    case 'passport_main':
      return 'Паспорт — разворот с фотографией';
    case 'registration':
      return 'Паспорт — регистрация';
    case 'snils':
      return 'СНИЛС';
    case 'inn':
      return 'ИНН';
    case 'policy':
      return 'Медицинский полис';
    default:
      return 'Другой документ';
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

class RecruitmentPipelineStage {
  final String id;
  final String companyId;
  final String systemKey;
  final String title;
  final String description;
  final String colorHex;
  final int sortOrder;
  final String legacyStatus;
  final bool isFinal;
  final bool isActive;

  const RecruitmentPipelineStage({
    required this.id,
    required this.companyId,
    required this.systemKey,
    required this.title,
    required this.description,
    required this.colorHex,
    required this.sortOrder,
    required this.legacyStatus,
    required this.isFinal,
    required this.isActive,
  });

  factory RecruitmentPipelineStage.fromMap(Map<String, dynamic> map) {
    return RecruitmentPipelineStage(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      systemKey: map['system_key']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      colorHex: map['color_hex']?.toString() ?? '#2F80ED',
      sortOrder: switch (map['sort_order']) {
        int value => value,
        num value => value.toInt(),
        _ => int.tryParse(map['sort_order']?.toString() ?? '') ?? 100,
      },
      legacyStatus: map['legacy_status']?.toString() ?? 'new',
      isFinal: map['is_final'] == true,
      isActive: map['is_active'] != false,
    );
  }
}

const List<String> recruitmentCustomFieldTypes = <String>[
  'text',
  'multiline',
  'number',
  'money',
  'phone',
  'email',
  'date',
  'boolean',
  'select',
  'multiselect',
];

String recruitmentCustomFieldTypeTitle(String type) {
  switch (type) {
    case 'multiline':
      return 'Большой текст';
    case 'number':
      return 'Число';
    case 'money':
      return 'Сумма';
    case 'phone':
      return 'Телефон';
    case 'email':
      return 'Email';
    case 'date':
      return 'Дата';
    case 'boolean':
      return 'Да / нет';
    case 'select':
      return 'Список';
    case 'multiselect':
      return 'Множественный список';
    default:
      return 'Строка';
  }
}

class RecruitmentCustomField {
  final String id;
  final String companyId;
  final String title;
  final String description;
  final String fieldType;
  final List<String> options;
  final bool isRequired;
  final bool showOnCard;
  final int sortOrder;
  final bool isActive;

  const RecruitmentCustomField({
    required this.id,
    required this.companyId,
    required this.title,
    this.description = '',
    required this.fieldType,
    required this.options,
    required this.isRequired,
    required this.showOnCard,
    required this.sortOrder,
    required this.isActive,
  });

  bool get supportsOptions =>
      fieldType == 'select' || fieldType == 'multiselect';

  String get typeTitle => recruitmentCustomFieldTypeTitle(fieldType);

  factory RecruitmentCustomField.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['options'];
    final options = rawOptions is List
        ? rawOptions
              .map((value) => value?.toString().trim() ?? '')
              .where((value) => value.isNotEmpty)
              .toList()
        : <String>[];
    return RecruitmentCustomField(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      fieldType: map['field_type']?.toString() ?? 'text',
      options: options,
      isRequired: map['is_required'] == true,
      showOnCard: map['show_on_card'] == true,
      sortOrder: switch (map['sort_order']) {
        int value => value,
        num value => value.toInt(),
        _ => int.tryParse(map['sort_order']?.toString() ?? '') ?? 100,
      },
      isActive: map['is_active'] != false,
    );
  }

  bool isEmptyValue(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is Iterable) return value.isEmpty;
    return false;
  }

  String formatValue(dynamic value) {
    if (isEmptyValue(value)) return '';
    if (fieldType == 'boolean') return value == true ? 'Да' : 'Нет';
    if (fieldType == 'money') {
      final number = value is num ? value : num.tryParse(value.toString());
      if (number == null) return value.toString();
      final text = number % 1 == 0
          ? number.toInt().toString()
          : number.toStringAsFixed(2);
      return '$text ₽';
    }
    if (value is Iterable) return value.map((item) => '$item').join(', ');
    return value.toString();
  }
}

class RecruitmentCrmConfiguration {
  final List<RecruitmentPipelineStage> stages;
  final List<RecruitmentCustomField> fields;

  const RecruitmentCrmConfiguration({
    required this.stages,
    required this.fields,
  });

  static const empty = RecruitmentCrmConfiguration(
    stages: <RecruitmentPipelineStage>[],
    fields: <RecruitmentCustomField>[],
  );

  RecruitmentPipelineStage? stageById(String id) {
    for (final stage in stages) {
      if (stage.id == id) return stage;
    }
    return null;
  }

  RecruitmentPipelineStage? stageForApplication(
    RecruitmentApplication application,
  ) {
    final direct = stageById(application.stageId);
    if (direct != null) return direct;
    final legacyKey = recruitmentStageKey(application.status);
    for (final stage in stages) {
      if (stage.systemKey == legacyKey) return stage;
    }
    return stages.isEmpty ? null : stages.first;
  }

  String customSearchText(RecruitmentApplication application) {
    return fields
        .map((field) => field.formatValue(application.customValue(field.id)))
        .where((value) => value.isNotEmpty)
        .join(' ');
  }
}

class RecruitmentWorkspaceData {
  final List<RecruitmentApplication> applications;
  final RecruitmentCrmConfiguration configuration;

  const RecruitmentWorkspaceData({
    required this.applications,
    required this.configuration,
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

String recruitmentStageDescription(String stage) {
  switch (stage) {
    case 'documents':
      return 'Собираем документы и медкомиссию';
    case 'problems':
      return 'Есть замечания или нужна проверка';
    case 'ready':
      return 'Проверены и готовы к отправке';
    case 'tickets':
      return 'Билеты куплены или кандидат в пути';
    case 'completed':
      return 'Прибыли на объект или оформлены';
    case 'reserve':
      return 'Подходят, но пока не запускаем';
    case 'rejected':
      return 'Отказ или кандидат не подходит';
    default:
      return 'Новые заявки и первичный контакт';
  }
}

String recruitmentStageDefaultStatus(String stage) {
  switch (stage) {
    case 'documents':
      return 'waiting_documents';
    case 'problems':
      return 'review';
    case 'ready':
      return 'approved';
    case 'tickets':
      return 'ticket_request';
    case 'completed':
      return 'arrived';
    case 'reserve':
      return 'reserve';
    case 'rejected':
      return 'rejected';
    default:
      return 'new';
  }
}

class RecruitmentDashboardData {
  final List<RecruitmentApplication> applications;
  final List<RecruitmentPipelineStage> stages;
  final Map<String, int> counts;

  const RecruitmentDashboardData({
    required this.applications,
    required this.stages,
    required this.counts,
  });

  int count(String stageId) => counts[stageId] ?? 0;
  int get total => applications.length;

  RecruitmentPipelineStage? stageFor(RecruitmentApplication application) {
    for (final stage in stages) {
      if (stage.id == application.stageId) return stage;
    }
    return null;
  }
}
