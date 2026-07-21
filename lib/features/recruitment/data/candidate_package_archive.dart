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

  const CandidatePackageResult({
    required this.bytes,
    required this.fileName,
    required this.includedFiles,
    required this.warnings,
  });
}

class CandidatePackageArchive {
  CandidatePackageArchive._();

  static CandidatePackageResult build({
    required AiAssistantAction action,
    required List<CandidatePackageAttachment> attachments,
    required List<String> warnings,
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
    final packageWarnings = List<String>.from(warnings);

    if (position.isEmpty) {
      packageWarnings.add(
        'Заявление на работу не создано: у кандидата не указана должность.',
      );
    } else {
      final employment = ExactDocxService.build(
        templateCode: 'employment_application',
        fileBaseName: 'Заявление_на_работу_$fullName',
        values: <String, String>{
          'employee_full_name': fullName,
          'employee_short_name': _shortName(fullName),
          'employee_position': position,
          'employment_date': employmentDate,
          'document_date': documentDate,
        },
      );
      _addBytes(
        archive,
        '01_Сформированные_формы/${employment.fileName}',
        employment.bytes,
      );
      includedFiles++;
    }

    for (var index = 0; index < attachments.length; index++) {
      final attachment = attachments[index];
      final name = _safeName(
        attachment.fileName.isEmpty
            ? '${attachment.documentType}_${index + 1}'
            : attachment.fileName,
      );
      _addBytes(
        archive,
        '02_Полученные_документы/${(index + 1).toString().padLeft(2, '0')}_$name',
        attachment.bytes,
      );
      includedFiles++;
    }

    packageWarnings.add(
      'Заявление на перечисление зарплаты не включено без проверенных банковских реквизитов кандидата.',
    );
    packageWarnings.add(
      'Согласие и трудовой договор будут включаться после утверждения точных форм ООО «СКБС».',
    );

    final manifest = _manifest(
      action: action,
      generatedAt: now,
      attachments: attachments,
      warnings: packageWarnings,
      employmentIncluded: position.isNotEmpty,
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
      fileName: 'Пакет_${_safeName(fullName)}_${DateFormat('yyyyMMdd').format(now)}.zip',
      includedFiles: includedFiles,
      warnings: packageWarnings,
    );
  }

  static String _manifest({
    required AiAssistantAction action,
    required DateTime generatedAt,
    required List<CandidatePackageAttachment> attachments,
    required List<String> warnings,
    required bool employmentIncluded,
  }) {
    final existing = attachments.isEmpty
        ? '— файлы не получены'
        : attachments
            .map((file) => '— ${_documentTitle(file.documentType)}: '
                '${file.fileName.isEmpty ? 'без названия' : file.fileName}')
            .join('\n');
    final missing = action.stringList('missing_documents');
    final missingText = missing.isEmpty
        ? '— базовый комплект по данным приложения собран'
        : missing.map((item) => '— ${_documentTitle(item)}').join('\n');

    return '''ПАКЕТ ДОКУМЕНТОВ КАНДИДАТА

Кандидат: ${action.text('full_name')}
Должность: ${action.text('position_title').isEmpty ? 'не указана' : action.text('position_title')}
Телефон: ${action.text('phone').isEmpty ? 'не указан' : action.text('phone')}
Гражданство: ${action.text('citizenship').isEmpty ? 'не указано' : action.text('citizenship')}
Статус: ${action.text('status').isEmpty ? 'не указан' : action.text('status')}
Согласие на обработку данных: ${action.boolean('consent_personal_data') ? 'получено' : 'не подтверждено'}
Дата готовности: ${action.text('ready_date').isEmpty ? 'не указана' : action.text('ready_date')}
Сформировано: ${DateFormat('dd.MM.yyyy HH:mm').format(generatedAt)}

СФОРМИРОВАННЫЕ ФОРМЫ
— Заявление на работу: ${employmentIncluded ? 'добавлено' : 'не добавлено'}
— Заявление на перечисление зарплаты: не добавлено без банковских реквизитов
— Согласие на обработку данных: ожидается утверждённая точная форма
— Трудовой договор: ожидается утверждённая точная форма

ПОЛУЧЕННЫЕ ДОКУМЕНТЫ
$existing

НЕ ХВАТАЕТ ПО ДАННЫМ ПРИЛОЖЕНИЯ
$missingText

ПРЕДУПРЕЖДЕНИЯ
${warnings.map((item) => '— $item').join('\n')}

ВАЖНО
Документы не подписаны и не отправлены. Перед печатью проверь ФИО, должность, даты, комплектность и содержимое каждого файла.
''';
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
    return clean
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  static String _documentTitle(String value) {
    return switch (value.trim()) {
      'passport' => 'Паспорт',
      'snils' => 'СНИЛС',
      'inn' => 'ИНН',
      'bank_details' => 'Банковские реквизиты',
      '' => 'Документ',
      _ => value,
    };
  }
}
