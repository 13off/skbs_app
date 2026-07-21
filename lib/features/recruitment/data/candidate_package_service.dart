import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;

import '../../ai/models/ai_assistant_result.dart';
import '../../documents/data/exact_docx_service.dart';
import 'candidate_document_repository.dart';

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

class CandidatePackageService {
  CandidatePackageService._();

  static const int maxPackageBytes = 80 * 1024 * 1024;

  static Future<CandidatePackageResult> build({
    required AiAssistantAction action,
    required String companyId,
  }) async {
    final applicationId = action.text('application_id');
    final fullName = action.text('full_name');
    if (applicationId.isEmpty || fullName.isEmpty) {
      throw StateError('Не хватает кандидата или ID анкеты');
    }

    final warnings = <String>[];
    final archive = Archive();
    var includedFiles = 0;
    var totalBytes = 0;
    final now = DateTime.now();
    final documentDate = DateFormat('dd.MM.yyyy').format(now);
    final employmentDate = _formatDate(
      action.text('ready_date').isEmpty
          ? action.text('date')
          : action.text('ready_date'),
      fallback: documentDate,
    );
    final position = action.text('position_title');

    if (position.isEmpty) {
      warnings.add('Заявление на работу не создано: у кандидата не указана должность.');
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
      totalBytes += employment.bytes.length;
      includedFiles++;
    }

    final documents = await CandidateDocumentRepository.fetchForApplication(
      companyId: companyId,
      applicationId: applicationId,
    );
    for (var index = 0; index < documents.length; index++) {
      final document = documents[index];
      if (!document.canDownload) {
        warnings.add(
          'Не добавлен «${document.originalName}»: файл ещё не перенесён в Storage.',
        );
        continue;
      }
      try {
        final bytes = await CandidateDocumentRepository.download(document);
        if (totalBytes + bytes.length > maxPackageBytes) {
          warnings.add(
            'Не добавлен «${document.originalName}»: пакет превысил бы 80 МБ.',
          );
          continue;
        }
        final name = _safeName(
          document.originalName.isEmpty
              ? '${document.documentType}_${index + 1}'
              : document.originalName,
        );
        _addBytes(
          archive,
          '02_Полученные_документы/${(index + 1).toString().padLeft(2, '0')}_$name',
          bytes,
        );
        totalBytes += bytes.length;
        includedFiles++;
      } catch (error) {
        warnings.add(
          'Не удалось добавить «${document.originalName}»: '
          '${error.toString().replaceFirst('Exception: ', '')}',
        );
      }
    }

    warnings.add(
      'Заявление на перечисление зарплаты не включено без проверенных банковских реквизитов кандидата.',
    );
    warnings.add(
      'Согласие и трудовой договор будут включаться после утверждения точных форм ООО «СКБС».',
    );

    final manifest = _manifest(
      action: action,
      generatedAt: now,
      documents: documents,
      warnings: warnings,
      employmentIncluded: position.isNotEmpty,
    );
    final manifestBytes = Uint8List.fromList(utf8.encode(manifest));
    _addBytes(archive, '00_ПРОВЕРИТЬ_ПЕРЕД_ПЕЧАТЬЮ.txt', manifestBytes);
    includedFiles++;

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null || encoded.isEmpty) {
      throw StateError('Не удалось собрать ZIP-пакет кандидата');
    }

    return CandidatePackageResult(
      bytes: Uint8List.fromList(encoded),
      fileName: 'Пакет_${_safeName(fullName)}_${DateFormat('yyyyMMdd').format(now)}.zip',
      includedFiles: includedFiles,
      warnings: warnings,
    );
  }

  static void download(CandidatePackageResult result) {
    final blob = html.Blob(<Object>[result.bytes], 'application/zip');
    final url = html.Url.createObjectUrlFromBlob(blob);
    try {
      html.AnchorElement(href: url)
        ..download = result.fileName
        ..click();
    } finally {
      html.Url.revokeObjectUrl(url);
    }
  }

  static String _manifest({
    required AiAssistantAction action,
    required DateTime generatedAt,
    required List<CandidateDocumentFile> documents,
    required List<String> warnings,
    required bool employmentIncluded,
  }) {
    final existing = documents.isEmpty
        ? '— файлы не получены'
        : documents
            .map((file) => '— ${_documentTitle(file.documentType)}: '
                '${file.originalName.isEmpty ? 'без названия' : file.originalName}')
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
