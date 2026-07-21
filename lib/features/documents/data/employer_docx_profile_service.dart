import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'exact_docx_service.dart';

abstract final class EmployerDocxProfileService {
  static ExactDocxResult apply({
    required ExactDocxResult source,
    required String employerName,
    required String representativeName,
  }) {
    final decoded = ZipDecoder().decodeBytes(source.bytes);
    final document = decoded.findFile('word/document.xml');
    if (document == null) return source;

    final rawContent = document.content;
    if (rawContent is! List<int>) {
      throw StateError('Не удалось прочитать XML кадрового DOCX');
    }

    final safeEmployer = _xmlValue(employerName);
    final safeRepresentative = _xmlValue(representativeName);
    final documentXml = utf8
        .decode(rawContent)
        .replaceAll('ООО «СКБС»', safeEmployer)
        .replaceAll('Ермолиной О.Б.', safeRepresentative);

    final rebuilt = Archive();
    for (final file in decoded.files) {
      final content = file.name == 'word/document.xml'
          ? Uint8List.fromList(utf8.encode(documentXml))
          : _bytes(file);
      rebuilt.addFile(ArchiveFile(file.name, content.length, content));
    }
    final encoded = ZipEncoder().encode(rebuilt);
    if (encoded == null || encoded.isEmpty) {
      throw StateError('Не удалось обновить профиль работодателя в DOCX');
    }
    return ExactDocxResult(
      bytes: Uint8List.fromList(encoded),
      missingFields: source.missingFields,
      fileName: source.fileName,
    );
  }

  static Uint8List _bytes(ArchiveFile file) {
    final content = file.content;
    if (content is Uint8List) return content;
    if (content is List<int>) return Uint8List.fromList(content);
    throw StateError('Не удалось прочитать файл ${file.name} внутри DOCX');
  }

  static String _xmlValue(String value) {
    final clean = value.trim().isEmpty ? '________________' : value.trim();
    return clean
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
