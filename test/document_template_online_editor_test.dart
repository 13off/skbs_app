import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('online editor rebuilds DOCX and protects system fields', () {
    final source = File(
      'lib/features/documents/data/document_template_online_editor.dart',
    ).readAsStringSync();

    expect(source, contains('final outputArchive = Archive();'));
    expect(source, contains('ArchiveFile(file.name, nextBytes.length, nextBytes)'));
    expect(source, isNot(contains('file.content =')));
    expect(source, contains('_placeholderPattern'));
    expect(source, contains("lower.contains('<w:sdt')"));
    expect(source, contains("lower.contains('<w:fldchar')"));
    expect(source, contains('block.isProtected'));
    expect(source, contains("'source_version_id': sourceVersion.id"));
    expect(source, contains("'source_kind': 'storage'"));
    expect(source, contains('current_version_id'));
  });
}