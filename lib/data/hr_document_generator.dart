import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

import '../models/employee.dart';
import '../models/employee_private_data.dart';

class HrDocumentTemplate {
  final String code;
  final String title;
  final String filePrefix;

  const HrDocumentTemplate({
    required this.code,
    required this.title,
    required this.filePrefix,
  });
}

class HrDocumentGenerationException implements Exception {
  final String message;

  const HrDocumentGenerationException(this.message);

  @override
  String toString() => message;
}

class HrDocumentGenerator {
  static final SupabaseClient _client = Supabase.instance.client;
  static final Map<String, Uint8List> _templateBytesCache =
      <String, Uint8List>{};

  static const employmentContract = HrDocumentTemplate(
    code: 'employment_contract',
    title: 'Трудовой договор',
    filePrefix: 'Трудовой договор',
  );

  static const personalDataConsent = HrDocumentTemplate(
    code: 'personal_data_consent',
    title: 'Согласие на обработку ПД',
    filePrefix: 'Согласие на обработку ПД',
  );

  static const employmentApplication = HrDocumentTemplate(
    code: 'employment_application',
    title: 'Заявление на трудоустройство',
    filePrefix: 'Заявление на трудоустройство',
  );

  static const salaryApplication = HrDocumentTemplate(
    code: 'salary_transfer_application',
    title: 'Заявление на заработную плату',
    filePrefix: 'Заявление на заработную плату',
  );

  static const dismissalApplication = HrDocumentTemplate(
    code: 'dismissal_application',
    title: 'Заявление на увольнение',
    filePrefix: 'Заявление на увольнение',
  );

  static const templates = <HrDocumentTemplate>[
    employmentContract,
    personalDataConsent,
    employmentApplication,
    salaryApplication,
    dismissalApplication,
  ];

  static Future<void> downloadDocument({
    required HrDocumentTemplate template,
    required Employee employee,
    required EmployeePrivateData privateData,
  }) async {
    final source = await _loadApprovedTemplate(template);
    final bytes = await _createDocxFromTemplate(
      templateBytes: source.bytes,
      employee: employee,
      privateData: privateData,
    );

    _downloadBytes(
      bytes: bytes,
      fileName:
          '${_safeFileName(template.filePrefix)}_${_safeFileName(employee.name)}.docx',
    );
  }

  static Future<_ApprovedTemplateSource> _loadApprovedTemplate(
    HrDocumentTemplate template,
  ) async {
    final rawCompanyId = await _client.rpc('current_user_company_id');
    final companyId =
        rawCompanyId?.toString().replaceAll('"', '').trim() ?? '';

    final rawRows = await _client
        .from('document_templates')
        .select('id, code, title, status, company_id, current_version_id')
        .eq('code', template.code);
    final rows = rawRows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    rows.sort((first, second) {
      final firstOwn = first['company_id']?.toString() == companyId;
      final secondOwn = second['company_id']?.toString() == companyId;
      if (firstOwn == secondOwn) return 0;
      return firstOwn ? -1 : 1;
    });

    Map<String, dynamic>? record;
    for (final row in rows) {
      if (row['status']?.toString() == 'active' &&
          (row['current_version_id']?.toString().trim().isNotEmpty ?? false)) {
        record = row;
        break;
      }
    }

    if (record == null) {
      throw HrDocumentGenerationException(
        'Для «${template.title}» пока нет утверждённого DOCX-шаблона. '
        'Загрузите его: Профиль → Инструменты → '
        'AppСтрой Трудоустройство → Шаблоны.',
      );
    }

    final versionId = record['current_version_id']!.toString();
    final rawVersion = await _client
        .from('document_template_versions')
        .select(
          'id, file_name, mime_type, source_kind, asset_path, storage_path, '
          'external_url, is_approved',
        )
        .eq('id', versionId)
        .single();
    final version = Map<String, dynamic>.from(rawVersion);

    if (version['is_approved'] != true) {
      throw HrDocumentGenerationException(
        'Текущая версия «${template.title}» ещё не утверждена.',
      );
    }

    final mimeType = version['mime_type']?.toString() ?? '';
    final fileName = version['file_name']?.toString() ?? '';
    final isDocx = mimeType.contains('wordprocessingml') ||
        fileName.toLowerCase().endsWith('.docx');
    if (!isDocx) {
      throw HrDocumentGenerationException(
        'Для «${template.title}» нужна утверждённая версия в формате DOCX.',
      );
    }

    final sourceKind = version['source_kind']?.toString() ?? '';
    switch (sourceKind) {
      case 'storage':
        final storagePath = version['storage_path']?.toString().trim() ?? '';
        if (storagePath.isEmpty) {
          throw HrDocumentGenerationException(
            'У шаблона «${template.title}» отсутствует файл в хранилище.',
          );
        }
        final cacheKey = 'storage:$storagePath';
        final cached = _templateBytesCache[cacheKey];
        if (cached != null) {
          return _ApprovedTemplateSource(Uint8List.fromList(cached));
        }
        try {
          final bytes = await _client.storage
              .from('document-templates')
              .download(storagePath);
          final safeBytes = Uint8List.fromList(bytes);
          _templateBytesCache[cacheKey] = safeBytes;
          return _ApprovedTemplateSource(Uint8List.fromList(safeBytes));
        } catch (_) {
          throw HrDocumentGenerationException(
            'Не удалось открыть DOCX-шаблон «${template.title}». '
            'Проверьте загруженную версию в разделе «Шаблоны».',
          );
        }
      case 'asset':
        final assetPath = version['asset_path']?.toString().trim() ?? '';
        if (assetPath.isEmpty) {
          throw HrDocumentGenerationException(
            'У шаблона «${template.title}» не указан файл приложения.',
          );
        }
        final cached = _templateBytesCache[assetPath];
        if (cached != null) {
          return _ApprovedTemplateSource(Uint8List.fromList(cached));
        }
        try {
          final data = await rootBundle.load(assetPath);
          final bytes = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
          final safeBytes = Uint8List.fromList(bytes);
          _templateBytesCache[assetPath] = safeBytes;
          return _ApprovedTemplateSource(Uint8List.fromList(safeBytes));
        } catch (_) {
          throw HrDocumentGenerationException(
            'Файл шаблона «${template.title}» отсутствует в сборке. '
            'Загрузите DOCX в закрытое хранилище AppСтрой.',
          );
        }
      case 'external':
        throw HrDocumentGenerationException(
          'Для «${template.title}» сохранена только внешняя ссылка. '
          'Загрузите исходный DOCX в AppСтрой, чтобы система могла заполнить его.',
        );
      default:
        throw HrDocumentGenerationException(
          'Для «${template.title}» не настроен источник DOCX-шаблона.',
        );
    }
  }

  static Future<Uint8List> _createDocxFromTemplate({
    required Uint8List templateBytes,
    required Employee employee,
    required EmployeePrivateData privateData,
  }) async {
    Archive inputArchive;
    try {
      inputArchive = ZipDecoder().decodeBytes(
        List<int>.from(templateBytes, growable: true),
      );
    } catch (_) {
      throw const HrDocumentGenerationException(
        'Загруженный шаблон повреждён или не является DOCX-файлом.',
      );
    }

    final outputArchive = Archive();
    final values = _templateValues(
      employee: employee,
      privateData: privateData,
    );

    for (final file in List<ArchiveFile>.from(inputArchive.files)) {
      if (!file.isFile) continue;

      final fileName = file.name;
      final originalBytes = _bytesFromArchiveFile(file);

      if (_shouldProcessXml(fileName)) {
        final xml = utf8.decode(originalBytes);
        final newXml = _replaceTokensOnly(xml: xml, values: values);
        final newBytes = utf8.encode(newXml);
        outputArchive.addFile(ArchiveFile(fileName, newBytes.length, newBytes));
      } else {
        outputArchive.addFile(
          ArchiveFile(fileName, originalBytes.length, originalBytes),
        );
      }
    }

    final zipped = ZipEncoder().encode(outputArchive);
    if (zipped == null) {
      throw const HrDocumentGenerationException(
        'Не удалось сформировать документ.',
      );
    }

    return Uint8List.fromList(List<int>.from(zipped, growable: true));
  }

  static bool _shouldProcessXml(String fileName) {
    return fileName == 'word/document.xml' ||
        fileName.startsWith('word/header') && fileName.endsWith('.xml') ||
        fileName.startsWith('word/footer') && fileName.endsWith('.xml');
  }

  static String _replaceTokensOnly({
    required String xml,
    required Map<String, String> values,
  }) {
    var result = xml;
    for (final entry in values.entries) {
      final key = entry.key;
      final value = _escapeXml(_oneLine(entry.value));
      result = result
          .replaceAll('{{$key}}', value)
          .replaceAll('{$key}', value)
          .replaceAll('[$key]', value);
    }
    return result;
  }

  static Map<String, String> _templateValues({
    required Employee employee,
    required EmployeePrivateData privateData,
  }) {
    final today = _todayText();
    final todayLong = _dateLongText(DateTime.now());
    final startDate = _normalizeDate(privateData.employmentStartDate);
    final startDateLong = _dateLongFromString(privateData.employmentStartDate);
    final dismissalDate = _normalizeDate(privateData.dismissalDate);
    final dismissalDateLong = _dateLongFromString(privateData.dismissalDate);
    final dailyRate = employee.dailyRate.toString();
    final shortFio = _shortFio(employee.name);
    final phone = privateData.phone.trim().isEmpty
        ? employee.phone.trim()
        : privateData.phone.trim();

    return <String, String>{
      'fio': employee.name,
      'ФИО': employee.name,
      'employee_fio': employee.name,
      'short_fio': shortFio,
      'position': employee.position,
      'Должность': employee.position,
      'phone': phone,
      'Телефон': phone,
      'object_name': employee.objectName,
      'Объект': employee.objectName,
      'daily_rate': dailyRate,
      'Ставка': dailyRate,
      'birth_date': _normalizeDate(privateData.birthDate),
      'birth_date_long': _dateLongFromString(privateData.birthDate),
      'birth_place': privateData.birthPlace,
      'passport_series': privateData.passportSeries,
      'passport_number': privateData.passportNumber,
      'passport_full': privateData.passportFull,
      'passport_issued_by': privateData.passportIssuedBy,
      'passport_issued_date': _normalizeDate(privateData.passportIssuedDate),
      'passport_issued_date_long': _dateLongFromString(
        privateData.passportIssuedDate,
      ),
      'passport_department_code': privateData.passportDepartmentCode,
      'snils': privateData.snils,
      'inn': privateData.inn,
      'registration_address': privateData.registrationAddress,
      'living_address': privateData.livingAddress,
      'clothes_size': privateData.clothesSize,
      'shoe_size': privateData.shoeSize,
      'bank_name': privateData.bankName,
      'bank_card': privateData.bankCard,
      'bank_account': privateData.bankAccount,
      'bank_bik': privateData.bankBik,
      'bank_corr_account': privateData.bankCorrAccount,
      'bank_inn': privateData.bankInn,
      'bank_kpp': privateData.bankKpp,
      'bank_okpo': privateData.bankOkpo,
      'bank_ogrn': privateData.bankOgrn,
      'bank_swift': privateData.bankSwift,
      'bank_address': privateData.bankAddress,
      'bank_office_address': privateData.bankOfficeAddress,
      'contract_number': privateData.contractNumber.isEmpty
          ? '_____________'
          : privateData.contractNumber,
      'employment_start_date': startDate.isEmpty ? today : startDate,
      'employment_start_date_long': startDateLong.isEmpty
          ? todayLong
          : startDateLong,
      'dismissal_date': dismissalDate.isEmpty ? today : dismissalDate,
      'dismissal_date_long': dismissalDateLong.isEmpty
          ? todayLong
          : dismissalDateLong,
      'comment': privateData.comment,
      'today': today,
      'today_long': todayLong,
      'date': today,
      'Дата': today,
    };
  }

  static String _oneLine(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _todayText() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
  }

  static String _normalizeDate(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';
    final isoMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
    if (isoMatch != null) {
      return '${isoMatch.group(3)}.${isoMatch.group(2)}.${isoMatch.group(1)}';
    }
    return text;
  }

  static String _dateLongFromString(String value) {
    final normalized = _normalizeDate(value);
    final match = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(normalized);
    if (match == null) return normalized;

    final day = int.tryParse(match.group(1) ?? '') ?? 0;
    final month = int.tryParse(match.group(2) ?? '') ?? 0;
    final year = int.tryParse(match.group(3) ?? '') ?? 0;
    if (day == 0 || month == 0 || year == 0) return normalized;
    return _dateLongText(DateTime(year, month, day));
  }

  static String _dateLongText(DateTime date) {
    const months = <String>[
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    return '« $day » $month ${date.year} г.';
  }

  static String _shortFio(String fio) {
    final parts = fio
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first;
    final surname = parts[0];
    final initials = parts.skip(1).map((part) => '${part[0]}.').join();
    return '$surname $initials';
  }

  static Uint8List _bytesFromArchiveFile(ArchiveFile file) {
    final content = file.content;
    if (content is Uint8List) {
      return Uint8List.fromList(List<int>.from(content, growable: true));
    }
    if (content is List<int>) {
      return Uint8List.fromList(List<int>.from(content, growable: true));
    }
    throw HrDocumentGenerationException(
      'Не удалось прочитать файл шаблона: ${file.name}',
    );
  }

  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _safeFileName(String value) {
    return value
        .trim()
        .replaceAll(' ', '_')
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .replaceAll(':', '_')
        .replaceAll('*', '_')
        .replaceAll('?', '_')
        .replaceAll('"', '_')
        .replaceAll('<', '_')
        .replaceAll('>', '_')
        .replaceAll('|', '_');
  }

  static void _downloadBytes({
    required Uint8List bytes,
    required String fileName,
  }) {
    final safeBytes = Uint8List.fromList(List<int>.from(bytes, growable: true));
    final blob = html.Blob(
      <Object>[safeBytes],
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }
}

class _ApprovedTemplateSource {
  final Uint8List bytes;

  const _ApprovedTemplateSource(this.bytes);
}
