import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/documents/data/document_template_online_editor.dart';

void main() {
  test('online editor changes ordinary text and preserves protected fields', () {
    final documentXml = '''
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p><w:r><w:t>Обычный текст договора</w:t></w:r></w:p>
    <w:p><w:r><w:t>{{employee_full_name}}</w:t></w:r></w:p>
    <w:sdt><w:sdtPr><w:tag w:val="company_name"/></w:sdtPr>
      <w:sdtContent><w:p><w:r><w:t>Название компании</w:t></w:r></w:p></w:sdtContent>
    </w:sdt>
  </w:body>
</w:document>
''';
    final archive = Archive()
      ..addFile(
        ArchiveFile(
          '[Content_Types].xml',
          8,
          utf8.encode('<Types/>'),
        ),
      )
      ..addFile(
        ArchiveFile(
          'word/document.xml',
          utf8.encode(documentXml).length,
          utf8.encode(documentXml),
        ),
      );
    final encoded = ZipEncoder().encode(archive);
    final bytes = Uint8List.fromList(encoded!);

    final draft = DocumentTemplateOnlineEditor.open(
      bytes,
      protectedTags: const ['company_name'],
    );

    expect(draft.editableCount, 1);
    expect(draft.protectedCount, 2);
    final editable = draft.blocks.singleWhere((block) => !block.isProtected);

    final saved = DocumentTemplateOnlineEditor.save(
      draft,
      <String, String>{editable.id: 'Новый текст договора'},
    );
    final savedArchive = ZipDecoder().decodeBytes(saved, verify: true);
    final savedFile = savedArchive.files.singleWhere(
      (file) => file.name == 'word/document.xml',
    );
    final savedXml = utf8.decode(savedFile.content as List<int>);

    expect(savedXml, contains('Новый текст договора'));
    expect(savedXml, contains('{{employee_full_name}}'));
    expect(savedXml, contains('w:tag w:val="company_name"'));
  });
}