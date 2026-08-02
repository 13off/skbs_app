import 'dart:typed_data';

import 'package:docx_template/docx_template.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/document_onboarding.dart';
import '../models/document_template.dart';
import 'document_template_repository.dart';
import 'document_workflow_repository.dart';

class DocumentGenerationResult {
  final EmployeeDocumentFileRecord file;
  final List<String> filledFields;
  final List<String> emptyFields;

  const DocumentGenerationResult({
    required this.file,
    required this.filledFields,
    required this.emptyFields,
  });
}

abstract final class DocumentGenerationService {
  static final SupabaseClient _client = Supabase.instance.client;

  static const Map<String, List<String>> _fieldAliases = {
    'employee_full_name': [
      'employee_full_name',
      'employee_name',
      'fio',
      'full_name',
      'ФИО сотрудника',
      'ФИО',
    ],
    'birth_date': ['birth_date', 'date_of_birth', 'Дата рождения'],
    'passport_series': ['passport_series', 'Серия паспорта'],
    'passport_number': ['passport_number', 'Номер паспорта'],
    'passport_issued_by': [
      'passport_issued_by',
      'passport_authority',
      'Кем выдан паспорт',
    ],
    'passport_issue_date': [
      'passport_issue_date',
      'passport_date',
      'Дата выдачи',
    ],
    'registration_address': [
      'registration_address',
      'address',
      'Адрес регистрации',
    ],
    'snils': ['snils', 'СНИЛС'],
    'inn': ['inn', 'ИНН'],
    'phone': ['phone', 'Телефон'],
    'bank_details': ['bank_details', 'Банковские реквизиты'],
    'company_name': ['company_name', 'Название компании'],
    'company_inn': ['company_inn', 'ИНН компании'],
    'manager_full_name': [
      'manager_full_name',
      'director_name',
      'ФИО руководителя',
    ],
    'position': ['position', 'Должность'],
    'object_name': ['object_name', 'object', 'Объект'],
    'start_date': ['start_date', 'Дата начала'],
    'compensation': [
      'compensation',
      'reward',
      'salary',
      'Сумма/вознаграждение',
      'Вознаграждение',
    ],
    'document_date': ['document_date', 'Дата документа'],
    'document_number': ['document_number', 'Номер документа'],
  };

  static Future<DocumentGenerationResult> generateAndUpload({
    required String companyId,
    required EmployeeOnboardingRecord onboarding,
    required DocumentTemplateRecord template,
    required Map<String, dynamic> fields,
  }) async {
    final version = template.currentVersion;
    if (!template.isActive || version == null || !version.isApproved) {
      throw StateError('Для генерации нужен утверждённый активный шаблон');
    }
    if (!_isDocx(version)) {
      throw StateError(
        'Автоматическая генерация MVP поддерживает утверждённые DOCX-шаблоны',
      );
    }
    final employeeId = onboarding.employeeId?.trim() ?? '';
    if (employeeId.isEmpty) {
      throw StateError('Сначала создайте или выберите карточку сотрудника');
    }

    final templateBytes = await _loadTemplateBytes(version);
    final docx = await DocxTemplate.fromBytes(templateBytes);
    final tags = <String>{
      ...docx.getTags().map((item) => item.trim()),
      ...version.contentControls.map((item) => item.trim()),
    }..removeWhere((item) => item.isEmpty);
    if (tags.isEmpty) {
      throw StateError(
        'В шаблоне не найдены защищённые системные поля Word',
      );
    }

    final values = _normalizedValues(fields);
    final requiredFields = _requiredFields(version);
    final content = Content();
    final filled = <String>[];
    final empty = <String>[];
    for (final tag in tags) {
      final value = _valueForTag(tag, values);
      content.add(TextContent(tag, value));
      if (value.trim().isEmpty) {
        empty.add(tag);
      } else {
        filled.add(tag);
      }
    }

    final missingRequired = requiredFields
        .where((field) => _valueForTag(field, values).trim().isEmpty)
        .toList(growable: false);
    if (missingRequired.isNotEmpty) {
      throw StateError(
        'Не заполнены обязательные поля: ${missingRequired.join(', ')}',
      );
    }

    final generated = await docx.generate(content);
    if (generated == null || generated.isEmpty) {
      throw StateError('Шаблон не удалось сформировать');
    }
    final bytes = Uint8List.fromList(generated);
    final date = DateTime.now();
    final fileName = _fileName(
      onboarding.personName,
      template.title,
      date,
      version.versionNo,
    );
    final file = await DocumentWorkflowRepository.uploadFile(
      companyId: companyId,
      onboardingId: onboarding.id,
      employeeId: employeeId,
      fileKind: 'generated',
      documentType: template.code,
      fileName: fileName,
      mimeType: DocumentTemplateRepository.docxMime,
      bytes: bytes,
      templateId: template.id,
      templateVersionId: version.id,
      metadata: <String, dynamic>{
        'template_title': template.title,
        'template_code': template.code,
        'template_version': version.versionNo,
        'generated_at': date.toUtc().toIso8601String(),
        'filled_fields': filled,
        'empty_optional_fields': empty,
        'generator': 'docx_template_0_4_0',
      },
    );
    return DocumentGenerationResult(
      file: file,
      filledFields: filled,
      emptyFields: empty,
    );
  }

  static Future<Uint8List> _loadTemplateBytes(
    DocumentTemplateVersion version,
  ) async {
    if (version.isAsset) {
      if (version.assetPath.trim().isEmpty) {
        throw StateError('У версии шаблона отсутствует asset-путь');
      }
      final data = await rootBundle.load(version.assetPath);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    }
    if (version.isStorage) {
      if (version.storagePath.trim().isEmpty) {
        throw StateError('У версии шаблона отсутствует файл в хранилище');
      }
      return _client.storage
          .from(DocumentTemplateRepository.bucketName)
          .download(version.storagePath);
    }
    throw StateError(
      'Внешний оригинал можно открыть, но нельзя безопасно генерировать '
      'без копирования утверждённой версии в закрытое хранилище AppСтрой',
    );
  }

  static bool _isDocx(DocumentTemplateVersion version) {
    return version.mimeType == DocumentTemplateRepository.docxMime ||
        version.fileName.toLowerCase().endsWith('.docx');
  }

  static Map<String, String> _normalizedValues(Map<String, dynamic> fields) {
    final result = <String, String>{};
    for (final entry in fields.entries) {
      final value = entry.value?.toString().trim() ?? '';
      result[_normalize(entry.key)] = value;
    }
    for (final entry in _fieldAliases.entries) {
      String value = '';
      for (final alias in entry.value) {
        final candidate = result[_normalize(alias)] ?? '';
        if (candidate.isNotEmpty) {
          value = candidate;
          break;
        }
      }
      result[_normalize(entry.key)] = value;
      for (final alias in entry.value) {
        result.putIfAbsent(_normalize(alias), () => value);
      }
    }
    return result;
  }

  static String _valueForTag(String tag, Map<String, String> values) {
    final normalized = _normalize(tag);
    final direct = values[normalized];
    if (direct != null) return direct;
    for (final entry in _fieldAliases.entries) {
      if (entry.value.any((alias) => _normalize(alias) == normalized)) {
        return values[_normalize(entry.key)] ?? '';
      }
    }
    return '';
  }

  static List<String> _requiredFields(DocumentTemplateVersion version) {
    final raw = version.fieldSchema['required_fields'];
    if (raw is! List) return const <String>[];
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[^a-zа-я0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static String _fileName(
    String personName,
    String documentTitle,
    DateTime date,
    int templateVersion,
  ) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final safePerson = _safePart(personName, fallback: 'Сотрудник');
    final safeTitle = _safePart(documentTitle, fallback: 'Документ');
    return '$safePerson — $safeTitle — $day.$month.${date.year} — '
        'template-v$templateVersion.docx';
  }

  static String _safePart(String value, {required String fallback}) {
    final clean = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-')
        .replaceAll(RegExp(r'\s+'), ' ');
    return clean.isEmpty ? fallback : clean;
  }
}
