import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;

import '../models/employee.dart';
import '../models/employee_private_data.dart';

class HrDocumentTemplate {
  final String title;
  final String assetPath;
  final String filePrefix;

  const HrDocumentTemplate({
    required this.title,
    required this.assetPath,
    required this.filePrefix,
  });
}

class HrDocumentGenerator {
  static const employmentContract = HrDocumentTemplate(
    title: 'Трудовой договор',
    assetPath: 'assets/templates/hr/employment_contract_template.docx',
    filePrefix: 'Трудовой договор',
  );

  static const personalDataConsent = HrDocumentTemplate(
    title: 'Согласие на обработку ПД',
    assetPath: 'assets/templates/hr/personal_data_consent_template.docx',
    filePrefix: 'Согласие на обработку ПД',
  );

  static const employmentApplication = HrDocumentTemplate(
    title: 'Заявление на трудоустройство',
    assetPath: 'assets/templates/hr/employment_application_template.docx',
    filePrefix: 'Заявление на трудоустройство',
  );

  static const salaryApplication = HrDocumentTemplate(
    title: 'Заявление на заработную плату',
    assetPath: 'assets/templates/hr/salary_application_template.docx',
    filePrefix: 'Заявление на заработную плату',
  );

  static const dismissalApplication = HrDocumentTemplate(
    title: 'Заявление на увольнение',
    assetPath: 'assets/templates/hr/dismissal_application_template.docx',
    filePrefix: 'Заявление на увольнение',
  );

  static const templates = [
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
    final bytes = await _createDocxFromTemplate(
      template: template,
      employee: employee,
      privateData: privateData,
    );

    _downloadBytes(
      bytes: bytes,
      fileName:
          '${_safeFileName(template.filePrefix)}_${_safeFileName(employee.name)}.docx',
    );
  }

  static Future<Uint8List> _createDocxFromTemplate({
    required HrDocumentTemplate template,
    required Employee employee,
    required EmployeePrivateData privateData,
  }) async {
    final templateData = await rootBundle.load(template.assetPath);
    final templateBytes = Uint8List.fromList(
      List<int>.from(templateData.buffer.asUint8List(), growable: true),
    );

    final inputArchive = ZipDecoder().decodeBytes(
      List<int>.from(templateBytes, growable: true),
    );

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
      throw Exception('Не удалось сформировать документ');
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
          .replaceAll('{{' + key + '}}', value)
          .replaceAll('{' + key + '}', value)
          .replaceAll('[' + key + ']', value);
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
    const months = [
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
    final year = date.year.toString();

    return '« $day » $month $year г.';
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

    throw Exception('Не удалось прочитать файл шаблона: ${file.name}');
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
      [safeBytes],
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
