import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';

import '../../ai/models/ai_assistant_result.dart';
import '../../documents/data/exact_docx_service.dart';

class CandidatePackageAttachment {
  final String documentType;
  final String fileName;
  final Uint8List bytes;

  const CandidatePackageAttachment({
    required this.documentType,
    required this.fileName,
    required this.bytes,
  });
}

class CandidatePackageResult {
  final Uint8List bytes;
  final String fileName;
  final int includedFiles;
  final List<String> warnings;
  final int sourceBytes;

  const CandidatePackageResult({
    required this.bytes,
    required this.fileName,
    required this.includedFiles,
    required this.warnings,
    this.sourceBytes = 0,
  });

  int get archiveBytes => bytes.length;
}

class CandidatePackageArchive {
  CandidatePackageArchive._();

  static CandidatePackageResult build({
    required AiAssistantAction action,
    required List<CandidatePackageAttachment> attachments,
    required List<String> warnings,
    int? sourceBytes,
    DateTime? generatedAt,
  }) {
    final fullName = action.text('full_name');
    if (fullName.isEmpty) throw StateError('Не указано ФИО кандидата');

    final now = generatedAt ?? DateTime.now();
    final archive = Archive();
    var includedFiles = 0;
    final documentDate = DateFormat('dd.MM.yyyy').format(now);
    final employmentDate = _formatDate(
      action.text('ready_date').isEmpty
          ? action.text('date')
          : action.text('ready_date'),
      fallback: documentDate,
    );
    final position = action.text('position_title');
    final objectName = action.text('object_name');
    final packageWarnings = List<String>.from(warnings);
    final formStates = <String, List<String>>{};

    final common = <String, String>{
      'employee_full_name': fullName,
      'employee_short_name': _shortName(fullName),
      'employee_position': position,
      'employee_phone': action.text('phone'),
      'employment_date': employmentDate,
      'document_date': documentDate,
      'work_address': objectName,
      'employer_name': 'ООО «СКБС»',
      'employer_representative': 'генерального директора Ермолиной О.Б.',
      'employer_basis': 'Устава',
      'work_schedule': 'согласно утверждённому графику работы',
    };

    includedFiles += _addGeneratedForm(
      archive: archive,
      templateCode: 'employment_application',
      fileBaseName: 'Заявление_на_работу_$fullName',
      values: common,
      formStates: formStates,
    );
    includedFiles += _addGeneratedForm(
      archive: archive,
      templateCode: 'salary_transfer_application',
      fileBaseName: 'Заявление_о_перечислении_зарплаты_$fullName',
      values: common,
      formStates: formStates,
    );
    includedFiles += _addGeneratedForm(
      archive: archive,
      templateCode: 'personal_data_consent',
      fileBaseName: 'Согласие_на_обработку_персональных_данных_$fullName',
      values: common,
      formStates: formStates,
    );
    includedFiles += _addGeneratedForm(
      archive: archive,
      templateCode: 'employment_contract',
      fileBaseName: 'Трудовой_договор_$fullName',
      values: common,
      formStates: formStates,
    );

    for (final entry in formStates.entries) {
      if (entry.value.isNotEmpty) {
        packageWarnings.add(
          '${_formTitle(entry.key)} содержит незаполненные поля: '
          '${entry.value.map(_fieldTitle).join(', ')}.',
        );
      }
    }
    packageWarnings.add(
      'Согласие и трудовой договор являются рабочими черновиками: перед '
      'подписанием проверь реквизиты работодателя, условия труда и действующую редакцию.',
    );

    final usedAttachmentNames = <String>{};
    for (var index = 0; index < attachments.length; index++) {
      final attachment = attachments[index];
      final safeName = _safeName(
        attachment.fileName.isEmpty
            ? '${attachment.documentType}_${index + 1}'
            : attachment.fileName,
      );
      final uniqueName = _uniqueName(safeName, usedAttachmentNames);
      _addBytes(
        archive,
        '02_Полученные_документы/'
        '${(index + 1).toString().padLeft(2, '0')}_$uniqueName',
        attachment.bytes,
      );
      includedFiles++;
    }

    final manifest = _manifest(
      action: action,
      generatedAt: now,
      attachments: attachments,
      warnings: packageWarnings,
      formStates: formStates,
    );
    _addBytes(
      archive,
      '00_ПРОВЕРИТЬ_ПЕРЕД_ПЕЧАТЬЮ.txt',
      Uint8List.fromList(utf8.encode(manifest)),
    );
    includedFiles++;

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null || encoded.isEmpty) {
      throw StateError('Не удалось собрать ZIP-пакет кандидата');
    }

    return CandidatePackageResult(
      bytes: Uint8List.fromList(encoded),
      fileName:
          'Пакет_${_safeName(fullName)}_${DateFormat('yyyyMMdd').format(now)}.zip',
      includedFiles: includedFiles,
      warnings: List<String>.unmodifiable(packageWarnings),
      sourceBytes: sourceBytes ??
          attachments.fold<int>(0, (sum, file) => sum + file.bytes.length),
    );
  }

  static int _addGeneratedForm({
    required Archive archive,
    required String templateCode,
    required String fileBaseName,
    required Map<String, String> values,
    required Map<String, List<String>> formStates,
  }) {
    final result = ExactDocxService.build(
      templateCode: templateCode,
      fileBaseName: fileBaseName,
      values: values,
    );
    formStates[templateCode] = result.missingFields;
    _addBytes(
      archive,
      '01_Сформированные_формы/${result.fileName}',
      result.bytes,
    );
    return 1;
  }

  static String _manifest({
    required AiAssistantAction action,
    required DateTime generatedAt,
    required List<CandidatePackageAttachment> attachments,
    required List<String> warnings,
    required Map<String, List<String>> formStates,
  }) {
    final existing = attachments.isEmpty
        ? '— файлы не получены'
        : attachments
            .map(
              (file) => '— ${_documentTitle(file.documentType)}: '
                  '${file.fileName.isEmpty ? 'без названия' : file.fileName}',
            )
            .join('\n');
    final missing = action.stringList('missing_documents');
    final missingText = missing.isEmpty
        ? '— базовый комплект по данным приложения собран'
        : missing.map((item) => '— ${_documentTitle(item)}').join('\n');
    final forms = <String>[
      'employment_application',
      'salary_transfer_application',
      'personal_data_consent',
      'employment_contract',
    ].map((code) {
      final fields = formStates[code] ?? const <String>[];
      return '— ${_formTitle(code)}: добавлено'
          '${fields.isEmpty ? '' : ', проверить ${fields.length} полей'}';
    }).join('\n');

    return '''ПАКЕТ ДОКУМЕНТОВ КАНДИДАТА

Кандидат: ${action.text('full_name')}
Должность: ${action.text('position_title').isEmpty ? 'не указана' : action.text('position_title')}
Объект: ${action.text('object_name').isEmpty ? 'не указан' : action.text('object_name')}
Телефон: ${action.text('phone').isEmpty ? 'не указан' : action.text('phone')}
Гражданство: ${action.text('citizenship').isEmpty ? 'не указано' : action.text('citizenship')}
Статус: ${action.text('status').isEmpty ? 'не указан' : action.text('status')}
Согласие на обработку данных: ${action.boolean('consent_personal_data') ? 'получено' : 'не подтверждено'}
Дата готовности: ${action.text('ready_date').isEmpty ? 'не указана' : action.text('ready_date')}
Сформировано: ${DateFormat('dd.MM.yyyy HH:mm').format(generatedAt)}

СФОРМИРОВАННЫЕ ФОРМЫ
$forms

ПОЛУЧЕННЫЕ ДОКУМЕНТЫ
$existing

НЕ ХВАТАЕТ ПО ДАННЫМ ПРИЛОЖЕНИЯ
$missingText

ПРЕДУПРЕЖДЕНИЯ
${warnings.map((item) => '— $item').join('\n')}

ВАЖНО
Документы не подписаны и не отправлены. Перед печатью проверь ФИО, паспортные данные, банковские реквизиты, должность, объект, даты, условия труда, реквизиты работодателя и содержимое каждого файла.
''';
  }

  static String _formTitle(String code) {
    return switch (code) {
      'employment_application' => 'Заявление на работу',
      'salary_transfer_application' => 'Заявление о перечислении зарплаты',
      'personal_data_consent' => 'Согласие на обработку персональных данных',
      'employment_contract' => 'Трудовой договор',
      _ => code,
    };
  }

  static String _fieldTitle(String field) {
    return switch (field) {
      'employee_full_name' => 'ФИО',
      'employee_short_name' => 'инициалы',
      'employee_position' => 'должность',
      'employee_phone' => 'телефон',
      'employment_date' => 'дата приёма',
      'contract_number' => 'номер договора',
      'contract_city' => 'город договора',
      'work_address' => 'место работы',
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
      'bank_account' => 'счёт',
      'bank_name' => 'банк',
      'bank_bik' => 'БИК',
      'bank_corr_account' => 'корр. счёт',
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
  }

  static void _addBytes(Archive archive, String path, Uint8List bytes) {
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  static String _formatDate(String value, {required String fallback}) {
    final parsed = DateTime.tryParse(value.trim());
    return parsed == null ? fallback : DateFormat('dd.MM.yyyy').format(parsed);
  }

  static String _shortName(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '';
    final buffer = StringBuffer(parts.first);
    for (final part in parts.skip(1).take(2)) {
      buffer.write(' ${part[0]}.');
    }
    return buffer.toString();
  }

  static String _safeName(String value) {
    final clean = value.trim().isEmpty ? 'file' : value.trim();
    final normalized = clean
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '_')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^[._ ]+|[._ ]+$'), '');
    return normalized.isEmpty ? 'file' : normalized;
  }

  static String _uniqueName(String name, Set<String> usedNames) {
    if (usedNames.add(name.toLowerCase())) return name;
    final dotIndex = name.lastIndexOf('.');
    final hasExtension = dotIndex > 0 && dotIndex < name.length - 1;
    final base = hasExtension ? name.substring(0, dotIndex) : name;
    final extension = hasExtension ? name.substring(dotIndex) : '';
    var suffix = 2;
    while (true) {
      final candidate = '${base}_$suffix$extension';
      if (usedNames.add(candidate.toLowerCase())) return candidate;
      suffix++;
    }
  }

  static String _documentTitle(String value) {
    return switch (value.trim()) {
      'passport' || 'passport_main' => 'Паспорт',
      'registration' => 'Регистрация',
      'snils' => 'СНИЛС',
      'inn' => 'ИНН',
      'policy' => 'Медицинский полис',
      'bank_details' => 'Банковские реквизиты',
      '' => 'Документ',
      _ => value,
    };
  }
}
