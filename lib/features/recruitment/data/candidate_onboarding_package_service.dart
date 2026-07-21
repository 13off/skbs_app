import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/employee_private_data_repository.dart';
import '../../compliance/data/company_compliance_repository.dart';
import '../../documents/data/employer_docx_profile_service.dart';
import '../../documents/data/exact_docx_service.dart';
import '../models/candidate_onboarding_candidate.dart';
import '../models/candidate_onboarding_models.dart';
import '../models/recruitment_models.dart';
import 'recruitment_repository.dart';

class CandidateOnboardingPackageResult {
  final Uint8List bytes;
  final String fileName;
  final Map<String, List<String>> missingFieldsByForm;
  final List<String> warnings;
  final int includedFiles;

  const CandidateOnboardingPackageResult({
    required this.bytes,
    required this.fileName,
    required this.missingFieldsByForm,
    required this.warnings,
    required this.includedFiles,
  });
}

abstract final class CandidateOnboardingPackageService {
  static final SupabaseClient _client = Supabase.instance.client;
  static const int _webLimit = 40 * 1024 * 1024;
  static const int _nativeLimit = 80 * 1024 * 1024;

  static int get maxPackageBytes => kIsWeb ? _webLimit : _nativeLimit;

  static Future<CandidateOnboardingPackageResult> build(
    CandidateOnboardingCandidate candidate,
  ) async {
    if (!candidate.consentPersonalData) {
      throw StateError(
        'Нельзя сформировать комплект без подтверждённого согласия кандидата',
      );
    }

    final compliance = await CompanyComplianceRepository.fetchSnapshot(
      candidate.companyId,
    );
    if (!candidate.isTestRecord && !compliance.realDocumentsAllowed) {
      throw StateError(
        'Production gate персональных данных закрыт. Для реального кандидата '
        'нужно утвердить профиль работодателя и закрыть все доказательства gate.',
      );
    }

    final warnings = <String>[];
    final archive = Archive();
    final missingFieldsByForm = <String, List<String>>{};
    var includedFiles = 0;
    var totalBytes = 0;

    if (candidate.isTestRecord) {
      warnings.add(
        'ТЕСТОВЫЙ РЕЖИМ: комплект нельзя использовать для реального трудоустройства.',
      );
    }

    final privateData = candidate.isTestRecord || candidate.employeeId.isEmpty
        ? null
        : await EmployeePrivateDataRepository.fetchByEmployeeId(
            candidate.employeeId,
          );
    var dailyRate = 0;
    if (candidate.employeeId.isNotEmpty) {
      final row = await _client
          .from('employees')
          .select('daily_rate')
          .eq('company_id', candidate.companyId)
          .eq('id', candidate.employeeId)
          .maybeSingle();
      dailyRate = (row?['daily_rate'] as num?)?.round() ?? 0;
    }

    final employer = compliance.employer;
    final now = DateTime.now();
    final documentDate = DateFormat('dd.MM.yyyy').format(now);
    final readyDate = privateData?.employmentStartDate.trim().isNotEmpty == true
        ? privateData!.employmentStartDate.trim()
        : candidate.readyDate == null
            ? documentDate
            : DateFormat('dd.MM.yyyy').format(candidate.readyDate!);
    final phone = privateData?.phone.trim().isNotEmpty == true
        ? privateData!.phone.trim()
        : candidate.phone.trim();
    final registrationAddress = privateData?.registrationAddress.trim() ?? '';
    final livingAddress = privateData?.livingAddress.trim().isNotEmpty == true
        ? privateData!.livingAddress.trim()
        : registrationAddress;
    final representative = <String>[
      employer.representativePosition.trim(),
      employer.representativeName.trim(),
    ].where((item) => item.isNotEmpty).join(' ');

    final values = <String, String>{
      'employee_full_name': candidate.fullName,
      'employee_short_name': _shortName(candidate.fullName),
      'employee_position': candidate.positionTitle,
      'employee_phone': phone,
      'employment_date': readyDate,
      'document_date': documentDate,
      'work_address': candidate.objectName,
      'employer_name': employer.legalName,
      'employer_representative': representative,
      'employer_basis': employer.representativeBasis,
      'work_schedule': employer.workSchedule,
      'salary_terms': _salaryTerms(
        employer.salaryTermsTemplate,
        dailyRate,
      ),
      'contract_number': privateData?.contractNumber ?? '',
      'contract_city': employer.contractCity,
      'employee_birth_date': privateData?.birthDate ?? '',
      'employee_birth_place': privateData?.birthPlace ?? '',
      'passport_series': privateData?.passportSeries ?? '',
      'passport_number': privateData?.passportNumber ?? '',
      'passport_issued_by': privateData?.passportIssuedBy ?? '',
      'passport_issued_date': privateData?.passportIssuedDate ?? '',
      'passport_department_code': privateData?.passportDepartmentCode ?? '',
      'registration_address': registrationAddress,
      'living_address': livingAddress,
      'employee_inn': privateData?.inn ?? '',
      'employee_snils': privateData?.snils ?? '',
      'bank_account': privateData?.bankAccount ?? '',
      'bank_name': privateData?.bankName ?? '',
      'bank_bik': privateData?.bankBik ?? '',
      'bank_corr_account': privateData?.bankCorrAccount ?? '',
      'bank_inn': privateData?.bankInn ?? '',
      'bank_kpp': privateData?.bankKpp ?? '',
      'bank_okpo': privateData?.bankOkpo ?? '',
      'bank_ogrn': privateData?.bankOgrn ?? '',
      'bank_swift': privateData?.bankSwift ?? '',
      'bank_address': privateData?.bankAddress ?? '',
      'bank_office_address': privateData?.bankOfficeAddress ?? '',
      'employer_address': employer.legalAddress,
      'employer_details': employer.employerDetails,
    };

    for (final code in candidateOnboardingFormCodes) {
      final raw = ExactDocxService.build(
        templateCode: code,
        values: values,
        fileBaseName: '${candidateOnboardingFormTitle(code)}_${candidate.fullName}',
      );
      final generated = EmployerDocxProfileService.apply(
        source: raw,
        employerName: employer.legalName,
        representativeName: employer.representativeName,
      );
      missingFieldsByForm[code] = generated.missingFields;
      _addBytes(
        archive,
        '01_Формы/${candidate.isTestRecord ? 'ТЕСТ_' : ''}${generated.fileName}',
        generated.bytes,
      );
      includedFiles++;
    }

    final documents = await RecruitmentRepository.fetchDocuments(
      companyId: candidate.companyId,
      applicationId: candidate.id,
    );
    final selectedDocuments = documents
        .where(
          (item) => item.isStored &&
              (candidate.isTestRecord ? item.isTestCopy : !item.isTestCopy),
        )
        .toList(growable: false);
    if (candidate.isTestRecord && selectedDocuments.isEmpty) {
      warnings.add('У тестовой записи нет тестовых копий исходных документов.');
    }

    final usedNames = <String>{};
    for (final document in selectedDocuments) {
      try {
        final bytes = await RecruitmentRepository.downloadStoredFile(
          bucket: document.storageBucket,
          path: document.storagePath,
        );
        if (totalBytes + bytes.length > maxPackageBytes) {
          warnings.add('Не добавлен «${document.title}»: превышен лимит пакета.');
          continue;
        }
        final fileName = _uniqueName(
          _safeName(
            document.originalName.trim().isEmpty
                ? '${document.documentType}.${_extension(document)}'
                : document.originalName,
          ),
          usedNames,
        );
        _addBytes(
          archive,
          '02_Исходные_документы/${document.isTestCopy ? 'ТЕСТ_' : ''}$fileName',
          bytes,
        );
        totalBytes += bytes.length;
        includedFiles++;
      } catch (error) {
        warnings.add('Не удалось добавить «${document.title}»: $error');
      }
    }

    final requiredTypes = <String>{'passport_main', 'snils', 'inn'};
    final availableTypes = selectedDocuments.map((item) => item.documentType).toSet();
    final missingDocuments = requiredTypes.difference(availableTypes).toList()..sort();
    if (missingDocuments.isNotEmpty) {
      warnings.add('Не хватает исходных документов: ${missingDocuments.join(', ')}.');
    }
    if (candidate.employeeId.isEmpty) {
      warnings.add(
        'Кандидат ещё не связан с сотрудником: паспортные и банковские реквизиты в формах не подставлены.',
      );
    } else if (!candidate.isTestRecord && privateData == null) {
      warnings.add(
        'У сотрудника нет закрытой карточки личных данных: часть полей форм осталась пустой.',
      );
    }
    if (!employer.legalDocumentsApproved) {
      warnings.add(
        'Согласие и трудовой договор не утверждены юристом. Реальное подписание запрещено.',
      );
    }
    if (!employer.hasRequiredEmployerDetails) {
      warnings.add(
        'В профиле работодателя заполнены не все обязательные реквизиты.',
      );
    }

    final manifest = _manifest(
      candidate: candidate,
      generatedAt: now,
      missingFieldsByForm: missingFieldsByForm,
      warnings: warnings,
      selectedDocuments: selectedDocuments,
      employerName: employer.legalName,
      gateEnabled: compliance.realDocumentsAllowed,
    );
    _addBytes(
      archive,
      '00_ПРОВЕРИТЬ_ПЕРЕД_ПЕЧАТЬЮ.txt',
      Uint8List.fromList(utf8.encode(manifest)),
    );
    includedFiles++;

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null || encoded.isEmpty) {
      throw StateError('Не удалось собрать кадровый ZIP');
    }
    final bytes = Uint8List.fromList(encoded);
    if (bytes.length > maxPackageBytes) {
      throw StateError('Готовый ZIP превышает допустимый размер');
    }
    return CandidateOnboardingPackageResult(
      bytes: bytes,
      fileName: '${candidate.isTestRecord ? 'ТЕСТ_' : ''}'
          'Кадровый_комплект_${_safeName(candidate.fullName)}_'
          '${DateFormat('yyyyMMdd').format(now)}.zip',
      missingFieldsByForm: Map<String, List<String>>.unmodifiable(
        missingFieldsByForm,
      ),
      warnings: List<String>.unmodifiable(warnings),
      includedFiles: includedFiles,
    );
  }

  static Future<void> save(CandidateOnboardingPackageResult result) async {
    await FileSaver.instance.saveFile(
      name: result.fileName.replaceFirst(RegExp(r'\.zip$', caseSensitive: false), ''),
      bytes: result.bytes,
      ext: 'zip',
      mimeType: MimeType.zip,
    );
  }

  static String _manifest({
    required CandidateOnboardingCandidate candidate,
    required DateTime generatedAt,
    required Map<String, List<String>> missingFieldsByForm,
    required List<String> warnings,
    required List<RecruitmentDocument> selectedDocuments,
    required String employerName,
    required bool gateEnabled,
  }) {
    final forms = candidateOnboardingFormCodes.map((code) {
      final missing = missingFieldsByForm[code] ?? const <String>[];
      return '— ${candidateOnboardingFormTitle(code)}: '
          '${missing.isEmpty ? 'готово' : 'проверить ${missing.length} полей'}';
    }).join('\n');
    final files = selectedDocuments.isEmpty
        ? '— документы не добавлены'
        : selectedDocuments
            .map((item) => '— ${item.title}${item.isTestCopy ? ' (ТЕСТ)' : ''}')
            .join('\n');
    final warningText = warnings.isEmpty
        ? '— предупреждений нет'
        : warnings.map((item) => '— $item').join('\n');
    return '''КАДРОВЫЙ КОМПЛЕКТ КАНДИДАТА

Режим: ${candidate.isTestRecord ? 'ТЕСТОВЫЙ' : 'РЕАЛЬНЫЙ'}
Production gate: ${gateEnabled ? 'ОТКРЫТ' : 'ЗАКРЫТ'}
Работодатель: ${employerName.trim().isEmpty ? 'не заполнен' : employerName}
Кандидат: ${candidate.fullName}
Должность: ${candidate.positionTitle}
Объект: ${candidate.objectName}
Телефон: ${candidate.phone}
Сотрудник связан: ${candidate.employeeId.isEmpty ? 'нет' : 'да'}
Согласие на обработку данных: ${candidate.consentPersonalData ? 'получено' : 'нет'}
Сформировано: ${DateFormat('dd.MM.yyyy HH:mm').format(generatedAt)}

ФОРМЫ
$forms

ИСХОДНЫЕ ДОКУМЕНТЫ
$files

ПРЕДУПРЕЖДЕНИЯ
$warningText

ПОРЯДОК
1. Проверить все незаполненные поля.
2. Распечатать документы.
3. Получить подписи работодателя и сотрудника.
4. Загрузить подписанные экземпляры в AppСтрой.
5. Не использовать тестовые копии для реального оформления.
''';
  }

  static String _salaryTerms(String template, int dailyRate) {
    final clean = template.trim();
    if (clean.isNotEmpty) {
      return clean.replaceAll('{daily_rate}', dailyRate > 0 ? '$dailyRate' : '');
    }
    return dailyRate > 0
        ? 'дневная ставка $dailyRate ₽, начисление по данным табеля'
        : '';
  }

  static void _addBytes(Archive archive, String path, Uint8List bytes) {
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  static String _shortName(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '';
    final buffer = StringBuffer(parts.first);
    for (final part in parts.skip(1).take(2)) {
      buffer.write(' ${part[0]}.');
    }
    return buffer.toString();
  }

  static String _safeName(String value) {
    final result = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return result.isEmpty ? 'Кандидат' : result;
  }

  static String _uniqueName(String name, Set<String> used) {
    if (used.add(name)) return name;
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final extension = dot > 0 ? name.substring(dot) : '';
    var index = 2;
    while (!used.add('${base}_$index$extension')) {
      index++;
    }
    return '${base}_$index$extension';
  }

  static String _extension(RecruitmentDocument document) {
    final name = document.originalName.toLowerCase();
    final index = name.lastIndexOf('.');
    if (index >= 0 && index < name.length - 1) return name.substring(index + 1);
    return switch (document.mimeType) {
      'application/pdf' => 'pdf',
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
  }
}
