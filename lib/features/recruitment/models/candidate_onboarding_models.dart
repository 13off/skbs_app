class CandidateOnboardingForm {
  final String id;
  final String companyId;
  final String applicationId;
  final String employeeId;
  final String formCode;
  final String status;
  final List<String> missingFields;
  final DateTime? generatedAt;
  final DateTime? printedAt;
  final DateTime? signedAt;
  final String storageBucket;
  final String storagePath;
  final String originalName;
  final String mimeType;
  final int sizeBytes;
  final DateTime updatedAt;

  const CandidateOnboardingForm({
    required this.id,
    required this.companyId,
    required this.applicationId,
    required this.employeeId,
    required this.formCode,
    required this.status,
    required this.missingFields,
    required this.generatedAt,
    required this.printedAt,
    required this.signedAt,
    required this.storageBucket,
    required this.storagePath,
    required this.originalName,
    required this.mimeType,
    required this.sizeBytes,
    required this.updatedAt,
  });

  factory CandidateOnboardingForm.fromMap(Map<String, dynamic> map) {
    DateTime? optionalDate(Object? value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
    }

    final missing = switch (map['missing_fields']) {
      List value => value.map((item) => item.toString()).toList(growable: false),
      _ => const <String>[],
    };

    return CandidateOnboardingForm(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      applicationId: map['application_id']?.toString() ?? '',
      employeeId: map['employee_id']?.toString() ?? '',
      formCode: map['form_code']?.toString() ?? '',
      status: map['status']?.toString() ?? 'not_generated',
      missingFields: missing,
      generatedAt: optionalDate(map['generated_at']),
      printedAt: optionalDate(map['printed_at']),
      signedAt: optionalDate(map['signed_at']),
      storageBucket: map['storage_bucket']?.toString() ?? '',
      storagePath: map['storage_path']?.toString() ?? '',
      originalName: map['original_name']?.toString() ?? '',
      mimeType: map['mime_type']?.toString() ?? '',
      sizeBytes: (map['size_bytes'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  bool get isGenerated => status != 'not_generated';
  bool get isPrinted => status == 'printed' || status == 'signed';
  bool get isSigned => status == 'signed';
  bool get hasSignedFile =>
      isSigned && storageBucket.trim().isNotEmpty && storagePath.trim().isNotEmpty;

  String get title => candidateOnboardingFormTitle(formCode);
  String get statusTitle => switch (status) {
        'ready_to_print' => 'Готов к печати',
        'printed' => 'Распечатан, ждёт подписи',
        'signed' => 'Подписан',
        _ => 'Не сформирован',
      };
}

const List<String> candidateOnboardingFormCodes = <String>[
  'employment_application',
  'salary_transfer_application',
  'personal_data_consent',
  'employment_contract',
];

String candidateOnboardingFormTitle(String code) => switch (code) {
      'employment_application' => 'Заявление на работу',
      'salary_transfer_application' => 'Заявление о перечислении зарплаты',
      'personal_data_consent' => 'Согласие на обработку персональных данных',
      'employment_contract' => 'Трудовой договор',
      _ => code,
    };

String candidateOnboardingFieldTitle(String field) => switch (field) {
      'employee_full_name' => 'ФИО',
      'employee_short_name' => 'инициалы',
      'employee_position' => 'должность',
      'employee_phone' => 'телефон',
      'employment_date' => 'дата приёма',
      'document_date' => 'дата документа',
      'contract_number' => 'номер договора',
      'contract_city' => 'город договора',
      'work_address' => 'место работы',
      'work_schedule' => 'график работы',
      'salary_terms' => 'условия оплаты',
      'passport_series' => 'серия паспорта',
      'passport_number' => 'номер паспорта',
      'passport_issued_by' => 'кем выдан паспорт',
      'passport_issued_date' => 'дата выдачи паспорта',
      'passport_department_code' => 'код подразделения',
      'registration_address' => 'адрес регистрации',
      'living_address' => 'адрес проживания',
      'employee_birth_date' => 'дата рождения',
      'employee_birth_place' => 'место рождения',
      'employee_inn' => 'ИНН',
      'employee_snils' => 'СНИЛС',
      'bank_account' => 'банковский счёт',
      'bank_name' => 'банк',
      'bank_bik' => 'БИК',
      'bank_corr_account' => 'корреспондентский счёт',
      'bank_inn' => 'ИНН банка',
      'bank_kpp' => 'КПП банка',
      'bank_okpo' => 'ОКПО банка',
      'bank_ogrn' => 'ОГРН банка',
      'bank_swift' => 'SWIFT',
      'bank_address' => 'адрес банка',
      'bank_office_address' => 'адрес отделения',
      'employer_address' => 'адрес работодателя',
      'employer_details' => 'реквизиты работодателя',
      _ => field,
    };
