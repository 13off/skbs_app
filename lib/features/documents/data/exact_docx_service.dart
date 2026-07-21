import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:universal_html/html.dart' as html;

class ExactDocxTemplateInfo {
  final String code;
  final String title;
  final String originalSha256;
  final List<String> requiredFields;

  const ExactDocxTemplateInfo({
    required this.code,
    required this.title,
    required this.originalSha256,
    required this.requiredFields,
  });
}

class ExactDocxResult {
  final Uint8List bytes;
  final List<String> missingFields;
  final String fileName;

  const ExactDocxResult({
    required this.bytes,
    required this.missingFields,
    required this.fileName,
  });
}

class ExactDocxService {
  ExactDocxService._();

  static const employmentApplication = ExactDocxTemplateInfo(
    code: 'employment_application',
    title: 'Заявление на работу',
    originalSha256:
        '7a43d67c2235a07e718b86125ecc69474392bbd2855d7a09a212ccc3faa646f1',
    requiredFields: <String>[
      'employee_full_name',
      'employee_position',
      'employment_date',
      'document_date',
      'employee_short_name',
    ],
  );

  static const salaryTransferApplication = ExactDocxTemplateInfo(
    code: 'salary_transfer_application',
    title: 'Заявление о перечислении зарплаты',
    originalSha256:
        'f7501f5b8d6f170840b67c24d5cf3a33377a55cf9cb92eff1c17ce47ec1406a9',
    requiredFields: <String>[
      'employee_full_name',
      'employee_position',
      'bank_account',
      'bank_name',
      'bank_bik',
      'bank_corr_account',
      'bank_inn',
      'bank_kpp',
      'bank_okpo',
      'bank_ogrn',
      'bank_swift',
      'bank_address',
      'bank_office_address',
      'document_date',
      'employee_short_name',
    ],
  );

  static ExactDocxTemplateInfo? templateFor(String code) {
    return switch (code.trim()) {
      'employment_application' => employmentApplication,
      'salary_transfer_application' => salaryTransferApplication,
      _ => null,
    };
  }

  static ExactDocxResult build({
    required String templateCode,
    required Map<String, String> values,
    required String fileBaseName,
  }) {
    final template = templateFor(templateCode);
    if (template == null) {
      throw UnsupportedError('Точный DOCX-шаблон «$templateCode» не поддерживается');
    }

    final normalizedValues = <String, String>{
      for (final entry in values.entries) entry.key: entry.value.trim(),
    };
    final missing = template.requiredFields
        .where((field) => (normalizedValues[field] ?? '').isEmpty)
        .toList(growable: false);

    final body = switch (template.code) {
      'employment_application' => _employmentBody(normalizedValues),
      'salary_transfer_application' => _salaryBody(normalizedValues),
      _ => throw UnsupportedError(template.code),
    };
    final documentXml = _document(body);
    final archive = Archive()
      ..addFile(_textFile('[Content_Types].xml', _contentTypes))
      ..addFile(_textFile('_rels/.rels', _rootRelationships))
      ..addFile(_textFile('word/document.xml', documentXml))
      ..addFile(_textFile('word/_rels/document.xml.rels', _documentRelationships))
      ..addFile(_textFile('word/settings.xml', _settings))
      ..addFile(_textFile('word/styles.xml', _styles))
      ..addFile(_textFile('word/fontTable.xml', _fontTable));
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null || encoded.isEmpty) {
      throw StateError('Не удалось собрать DOCX');
    }

    return ExactDocxResult(
      bytes: Uint8List.fromList(encoded),
      missingFields: missing,
      fileName: '${_safeFileName(fileBaseName)}.docx',
    );
  }

  static void download(ExactDocxResult result) {
    final blob = html.Blob(
      <Object>[result.bytes],
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    final url = html.Url.createObjectUrlFromBlob(blob);
    try {
      html.AnchorElement(href: url)
        ..download = result.fileName
        ..click();
    } finally {
      html.Url.revokeObjectUrl(url);
    }
  }

  static ArchiveFile _textFile(String path, String value) {
    final bytes = utf8.encode(value);
    return ArchiveFile(path, bytes.length, bytes);
  }

  static String _safeFileName(String value) {
    final clean = value.trim().isEmpty ? 'document' : value.trim();
    return clean
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  static String _value(Map<String, String> values, String key) {
    final value = values[key]?.trim() ?? '';
    return _escapeXml(value.isEmpty ? '________________' : value);
  }

  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _document(String body) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:body>$body</w:body></w:document>';

  static String _run(
    String text, {
    bool bold = false,
    int? size,
    bool breakBefore = false,
    bool preserve = false,
  }) {
    final properties = <String>[
      if (bold) '<w:b/>',
      if (size != null) '<w:sz w:val="$size"/>',
      '<w:lang w:val="ru-RU"/>',
    ].join();
    return '<w:r><w:rPr>$properties</w:rPr>'
        '${breakBefore ? '<w:br/>' : ''}'
        '<w:t${preserve ? ' xml:space="preserve"' : ''}>$text</w:t></w:r>';
  }

  static String _paragraph(
    String runs, {
    String? align,
    int after = 0,
    int? firstLine,
  }) {
    return '<w:p><w:pPr><w:spacing w:after="$after" w:line="240" '
        'w:lineRule="auto"/>'
        '${align == null ? '' : '<w:jc w:val="$align"/>'}'
        '${firstLine == null ? '' : '<w:ind w:firstLine="$firstLine"/>'}'
        '</w:pPr>$runs</w:p>';
  }

  static String _blank([int count = 1]) => List<String>.filled(
        count,
        _paragraph(''),
      ).join();

  static String _employmentBody(Map<String, String> values) {
    final fullName = _value(values, 'employee_full_name');
    final position = _value(values, 'employee_position');
    final employmentDate = _value(values, 'employment_date');
    final documentDate = _value(values, 'document_date');
    final shortName = _value(values, 'employee_short_name');

    return <String>[
      _paragraph(
        '${_run('Генеральному')}${_run(' ', preserve: true)}'
        '${_run('директору')}${_run(' ООО «СКБС»', preserve: true)}',
        align: 'right',
      ),
      _paragraph(_run('Ермолиной О.Б.'), align: 'right'),
      _paragraph(
        '${_run('от ', preserve: true)}${_run(fullName)}',
        align: 'right',
      ),
      _blank(5),
      _paragraph(_run('Заявление'), align: 'center', after: 360),
      _paragraph(_run('Прошу принять меня на работу в ООО «СКБС» по должности')),
      _paragraph(
        '${_run(position)}${_run('  с ', preserve: true)}'
        '${_run(employmentDate)}${_run(' г.', preserve: true)}',
      ),
      _blank(4),
      _borderlessSignatureTable(
        left: '$documentDate г.',
        right: '________________ / $shortName /',
      ),
      '<w:p/>',
      _section(pageWidth: 11906, pageHeight: 16838),
    ].join();
  }

  static String _salaryBody(Map<String, String> values) {
    final rows = <(String, String)>[
      ('Валюта получаемого перевода', 'Российский рубль (RUB)'),
      ('Получатель', _value(values, 'employee_full_name')),
      ('Номер счёта', _value(values, 'bank_account')),
      ('Банк получателя', _value(values, 'bank_name')),
      ('БИК', _value(values, 'bank_bik')),
      ('Корр. счёт', _value(values, 'bank_corr_account')),
      ('ИНН', _value(values, 'bank_inn')),
      ('КПП', _value(values, 'bank_kpp')),
      ('ОКПО', _value(values, 'bank_okpo')),
      ('ОГРН', _value(values, 'bank_ogrn')),
      ('SWIFT-код', _value(values, 'bank_swift')),
      ('Почтовый адрес банка', _value(values, 'bank_address')),
      ('Почтовый адрес доп.офиса', _value(values, 'bank_office_address')),
    ];
    final fullName = _value(values, 'employee_full_name');
    final position = _value(values, 'employee_position');
    final documentDate = _value(values, 'document_date');
    final shortName = _value(values, 'employee_short_name');

    return <String>[
      _paragraph(
        '${_run('Генеральному Директору ООО «СКБС»')}'
        '${_run('Ермолиной О.Б.', breakBefore: true)}'
        '${_run('от ', breakBefore: true, preserve: true)}${_run(fullName)}'
        '${_run('должность: ', breakBefore: true, preserve: true)}${_run(position)}',
        align: 'right',
      ),
      _blank(3),
      _paragraph(_run('ЗАЯВЛЕНИЕ', bold: true, size: 28), align: 'center', after: 360),
      _paragraph(
        _run('Прошу перечислять мою заработную плату по указанным реквизитам банковского счёта.'),
        after: 320,
        firstLine: 709,
      ),
      _paragraph(_run('Реквизиты получателя зарплаты:', bold: true), after: 120),
      _detailsTable(rows),
      _paragraph(''),
      _salarySignatureTable(documentDate: documentDate, shortName: shortName),
      '<w:p/>',
      _section(pageWidth: 12240, pageHeight: 15840),
    ].join();
  }

  static String _detailsTable(List<(String, String)> rows) {
    final body = rows.map((row) => _detailsRow(row.$1, row.$2)).join();
    return '<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/>'
        '<w:tblW w:w="0" w:type="auto"/>'
        '<w:tblLook w:val="04A0" w:firstRow="1" w:lastRow="0" '
        'w:firstColumn="1" w:lastColumn="0" w:noHBand="0" w:noVBand="1"/>'
        '</w:tblPr><w:tblGrid><w:gridCol w:w="3685"/>'
        '<w:gridCol w:w="5953"/></w:tblGrid>$body</w:tbl>';
  }

  static String _detailsRow(String label, String value) {
    return '<w:tr>${_detailCell(label, labelCell: true)}'
        '${_detailCell(value)}</w:tr>';
  }

  static String _detailCell(String value, {bool labelCell = false}) {
    const borders = '<w:tcBorders>'
        '<w:top w:val="single" w:sz="4" w:space="0" w:color="BFBFBF"/>'
        '<w:left w:val="single" w:sz="4" w:space="0" w:color="BFBFBF"/>'
        '<w:bottom w:val="single" w:sz="4" w:space="0" w:color="BFBFBF"/>'
        '<w:right w:val="single" w:sz="4" w:space="0" w:color="BFBFBF"/>'
        '</w:tcBorders>';
    return '<w:tc><w:tcPr><w:tcW w:w="${labelCell ? 3685 : 5953}" '
        'w:type="dxa"/>$borders'
        '${labelCell ? '<w:shd w:val="clear" w:color="auto" w:fill="F2F2F2"/>' : ''}'
        '</w:tcPr>${_paragraph(_run(value, bold: labelCell, size: labelCell ? 22 : null))}</w:tc>';
  }

  static String _borderlessSignatureTable({
    required String left,
    required String right,
  }) {
    return '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/>'
        '<w:jc w:val="center"/><w:tblBorders>'
        '<w:top w:val="nil"/><w:left w:val="nil"/><w:bottom w:val="nil"/>'
        '<w:right w:val="nil"/><w:insideH w:val="nil"/><w:insideV w:val="nil"/>'
        '</w:tblBorders></w:tblPr><w:tblGrid><w:gridCol w:w="3969"/>'
        '<w:gridCol w:w="5669"/></w:tblGrid><w:tr>'
        '${_simpleCell(left, width: 3969)}'
        '${_simpleCell(right, width: 5669, align: 'right')}'
        '</w:tr></w:tbl>';
  }

  static String _salarySignatureTable({
    required String documentDate,
    required String shortName,
  }) {
    return '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/></w:tblPr>'
        '<w:tblGrid><w:gridCol w:w="3118"/><w:gridCol w:w="3118"/>'
        '<w:gridCol w:w="3288"/></w:tblGrid>'
        '<w:tr>${_simpleCell(documentDate, width: 3118)}'
        '${_simpleCell('_____________________', width: 3118, align: 'center')}'
        '${_simpleCell('/ $shortName /', width: 3288, align: 'center')}</w:tr>'
        '<w:tr>${_simpleCell('', width: 3118)}'
        '${_simpleCell('(подпись)', width: 3118, align: 'center', size: 20)}'
        '${_simpleCell('(ФИО)', width: 3288, align: 'center', size: 20)}</w:tr>'
        '</w:tbl>';
  }

  static String _simpleCell(
    String text, {
    required int width,
    String? align,
    int? size,
  }) {
    return '<w:tc><w:tcPr><w:tcW w:w="$width" w:type="dxa"/>'
        '<w:tcBorders><w:top w:val="nil"/><w:left w:val="nil"/>'
        '<w:bottom w:val="nil"/><w:right w:val="nil"/></w:tcBorders>'
        '</w:tcPr>${_paragraph(_run(text, size: size), align: align)}</w:tc>';
  }

  static String _section({required int pageWidth, required int pageHeight}) {
    return '<w:sectPr><w:pgSz w:w="$pageWidth" w:h="$pageHeight"/>'
        '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" '
        'w:left="1134" w:header="720" w:footer="720" w:gutter="0"/>'
        '<w:cols w:space="720"/><w:docGrid w:linePitch="360"/></w:sectPr>';
  }

  static const _contentTypes = '<?xml version="1.0" encoding="UTF-8"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/word/fontTable.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.fontTable+xml"/>'
      '<Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>'
      '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
      '</Types>';

  static const _rootRelationships = '<?xml version="1.0" encoding="UTF-8"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
      '</Relationships>';

  static const _documentRelationships = '<?xml version="1.0" encoding="UTF-8"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '<Relationship Id="rId6" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable" Target="fontTable.xml"/>'
      '<Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/>'
      '</Relationships>';

  static const _settings = '<?xml version="1.0" encoding="UTF-8"?>'
      '<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:zoom w:percent="100"/><w:defaultTabStop w:val="720"/>'
      '<w:characterSpacingControl w:val="doNotCompress"/>'
      '<w:decimalSymbol w:val=","/><w:listSeparator w:val=";"/>'
      '</w:settings>';

  static const _styles = '<?xml version="1.0" encoding="UTF-8"?>'
      '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Times New Roman" '
      'w:hAnsi="Times New Roman"/><w:sz w:val="24"/><w:szCs w:val="24"/>'
      '<w:lang w:val="ru-RU"/></w:rPr></w:rPrDefault><w:pPrDefault/>'
      '</w:docDefaults><w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
      '<w:name w:val="Normal"/></w:style><w:style w:type="table" w:default="1" '
      'w:styleId="TableNormal"><w:name w:val="Normal Table"/></w:style>'
      '<w:style w:type="table" w:styleId="TableGrid"><w:name w:val="Table Grid"/>'
      '<w:basedOn w:val="TableNormal"/><w:tblPr><w:tblBorders>'
      '<w:top w:val="single" w:sz="4"/><w:left w:val="single" w:sz="4"/>'
      '<w:bottom w:val="single" w:sz="4"/><w:right w:val="single" w:sz="4"/>'
      '<w:insideH w:val="single" w:sz="4"/><w:insideV w:val="single" w:sz="4"/>'
      '</w:tblBorders></w:tblPr></w:style></w:styles>';

  static const _fontTable = '<?xml version="1.0" encoding="UTF-8"?>'
      '<w:fonts xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:font w:name="Times New Roman"><w:family w:val="roman"/>'
      '<w:pitch w:val="variable"/></w:font></w:fonts>';
}
