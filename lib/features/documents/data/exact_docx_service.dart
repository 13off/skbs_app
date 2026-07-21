import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

class ExactDocxTemplateInfo {
  final String code;
  final String title;
  final String originalSha256;
  final List<String> requiredFields;
  final bool legalReviewRequired;

  const ExactDocxTemplateInfo({
    required this.code,
    required this.title,
    required this.originalSha256,
    required this.requiredFields,
    this.legalReviewRequired = false,
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

  static const personalDataConsent = ExactDocxTemplateInfo(
    code: 'personal_data_consent',
    title: 'Согласие на обработку персональных данных',
    originalSha256:
        '20405bf4424884ebad315d6b3d74ee5d7f62dc4ee306056e1a3bfc3fb79b079e',
    legalReviewRequired: true,
    requiredFields: <String>[
      'employee_full_name',
      'passport_series',
      'passport_number',
      'passport_issued_by',
      'passport_issued_date',
      'passport_department_code',
      'living_address',
      'employee_phone',
      'document_date',
      'employee_short_name',
      'employer_name',
      'employer_address',
    ],
  );

  static const employmentContract = ExactDocxTemplateInfo(
    code: 'employment_contract',
    title: 'Трудовой договор',
    originalSha256:
        '9d0fdbb32df89d846f9ccda2bda14711bba6ac6441319dabe3b9bca12c969d4d',
    legalReviewRequired: true,
    requiredFields: <String>[
      'contract_number',
      'document_date',
      'contract_city',
      'employer_name',
      'employer_representative',
      'employer_basis',
      'employee_full_name',
      'employee_position',
      'work_address',
      'employment_date',
      'work_schedule',
      'salary_terms',
      'employee_birth_date',
      'employee_birth_place',
      'passport_series',
      'passport_number',
      'passport_issued_by',
      'passport_issued_date',
      'passport_department_code',
      'registration_address',
      'employee_phone',
      'employee_inn',
      'employee_snils',
      'employer_details',
    ],
  );

  static ExactDocxTemplateInfo? templateFor(String code) {
    return switch (code.trim()) {
      'employment_application' => employmentApplication,
      'salary_transfer_application' => salaryTransferApplication,
      'personal_data_consent' => personalDataConsent,
      'employment_contract' => employmentContract,
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
      'personal_data_consent' => _consentBody(normalizedValues),
      'employment_contract' => _contractBody(normalizedValues),
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

  static String _heading(String text) =>
      _paragraph(_run(text, bold: true), align: 'center', after: 180);

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

  static String _consentBody(Map<String, String> values) {
    final fullName = _value(values, 'employee_full_name');
    final series = _value(values, 'passport_series');
    final number = _value(values, 'passport_number');
    final issuedBy = _value(values, 'passport_issued_by');
    final issuedDate = _value(values, 'passport_issued_date');
    final departmentCode = _value(values, 'passport_department_code');
    final livingAddress = _value(values, 'living_address');
    final phone = _value(values, 'employee_phone');
    final employerName = _value(values, 'employer_name');
    final employerAddress = _value(values, 'employer_address');
    final documentDate = _value(values, 'document_date');
    final shortName = _value(values, 'employee_short_name');

    const categories = <String>[
      'фамилия, имя, отчество; пол, возраст, дата и место рождения;',
      'паспортные данные, адрес регистрации и фактического проживания, телефон;',
      'сведения об образовании, квалификации, трудовом стаже и воинской обязанности;',
      'СНИЛС, ИНН, сведения о приёме, переводе, увольнении, рабочем времени и доходах;',
      'иные сведения, содержащиеся в трудовом договоре и кадровых документах.',
    ];

    return <String>[
      _paragraph(
        _run('СОГЛАСИЕ НА ХРАНЕНИЕ И ОБРАБОТКУ ПЕРСОНАЛЬНЫХ ДАННЫХ', bold: true, size: 28),
        align: 'center',
        after: 300,
      ),
      _paragraph(
        '${_run('Я, ', preserve: true)}${_run(fullName)}${_run(', паспорт: серия ', preserve: true)}'
        '${_run(series)}${_run(' № ', preserve: true)}${_run(number)}${_run(', выдан ', preserve: true)}'
        '${_run(issuedBy)}${_run(', дата выдачи ', preserve: true)}${_run(issuedDate)}'
        '${_run(', код подразделения ', preserve: true)}${_run(departmentCode)}${_run(', проживающий по адресу: ', preserve: true)}'
        '${_run(livingAddress)}${_run(', телефон: ', preserve: true)}${_run(phone)}${_run(', в соответствии со статьёй 9 Федерального закона от 27.07.2006 № 152-ФЗ даю согласие ', preserve: true)}'
        '${_run(employerName)}${_run(', расположенному по адресу: ', preserve: true)}${_run(employerAddress)}'
        '${_run(', на хранение и обработку моих персональных данных.', preserve: true)}',
        firstLine: 709,
        after: 180,
      ),
      _paragraph(_run('К моим персональным данным относится следующая информация:', bold: true), after: 100),
      ...categories.map((item) => _paragraph(_run('— $item'), firstLine: 360, after: 60)),
      _paragraph(
        _run(
          'Согласен на сбор, систематизацию, накопление, хранение, уточнение, использование, обезличивание, блокирование и уничтожение персональных данных с использованием средств автоматизации и без них в целях оформления и сопровождения трудовых отношений, исполнения требований законодательства, расчёта и выплаты заработной платы.',
        ),
        firstLine: 709,
        after: 160,
      ),
      _paragraph(
        _run(
          'Передача допускается в объёме, необходимом для исполнения закона и договора, налоговым органам, государственным внебюджетным фондам, банкам и иным уполномоченным лицам. Срок хранения определяется законодательством и номенклатурой дел работодателя.',
        ),
        firstLine: 709,
        after: 160,
      ),
      _paragraph(
        _run(
          'Согласие действует с момента подписания и может быть отозвано письменным заявлением, если дальнейшая обработка не требуется по закону. Обязуюсь своевременно сообщать об изменении предоставленных сведений.',
        ),
        firstLine: 709,
        after: 300,
      ),
      _borderlessSignatureTable(
        left: '$documentDate г.',
        right: '________________ / $shortName /',
      ),
      _paragraph(_run('Перед подписанием проверить реквизиты оператора персональных данных и сроки хранения.', size: 20), after: 0),
      '<w:p/>',
      _section(pageWidth: 11906, pageHeight: 16838),
    ].join();
  }

  static String _contractBody(Map<String, String> values) {
    final contractNumber = _value(values, 'contract_number');
    final documentDate = _value(values, 'document_date');
    final city = _value(values, 'contract_city');
    final employerName = _value(values, 'employer_name');
    final representative = _value(values, 'employer_representative');
    final basis = _value(values, 'employer_basis');
    final employee = _value(values, 'employee_full_name');
    final position = _value(values, 'employee_position');
    final workAddress = _value(values, 'work_address');
    final employmentDate = _value(values, 'employment_date');
    final schedule = _value(values, 'work_schedule');
    final salary = _value(values, 'salary_terms');
    final birthDate = _value(values, 'employee_birth_date');
    final birthPlace = _value(values, 'employee_birth_place');
    final passportSeries = _value(values, 'passport_series');
    final passportNumber = _value(values, 'passport_number');
    final passportIssuedBy = _value(values, 'passport_issued_by');
    final passportIssuedDate = _value(values, 'passport_issued_date');
    final departmentCode = _value(values, 'passport_department_code');
    final registrationAddress = _value(values, 'registration_address');
    final phone = _value(values, 'employee_phone');
    final inn = _value(values, 'employee_inn');
    final snils = _value(values, 'employee_snils');
    final employerDetails = _value(values, 'employer_details');

    return <String>[
      _paragraph(_run('ТРУДОВОЙ ДОГОВОР № $contractNumber', bold: true, size: 28), align: 'center', after: 220),
      _borderlessSignatureTable(left: 'г. $city', right: '$documentDate г.'),
      _paragraph(
        '${_run(employerName)}${_run(' в лице ', preserve: true)}${_run(representative)}'
        '${_run(', действующего на основании ', preserve: true)}${_run(basis)}'
        '${_run(', именуемый в дальнейшем «Работодатель», с одной стороны, и гражданин ', preserve: true)}'
        '${_run(employee)}${_run(', именуемый в дальнейшем «Работник», с другой стороны, заключили настоящий договор.', preserve: true)}',
        firstLine: 709,
        after: 180,
      ),
      _heading('1. ПРЕДМЕТ ДОГОВОРА'),
      _paragraph(_run('1.1. Работник принимается на должность $position по основному месту работы.'), firstLine: 360, after: 80),
      _paragraph(_run('1.2. Место выполнения работы: $workAddress.'), firstLine: 360, after: 80),
      _paragraph(_run('1.3. Дата начала работы: $employmentDate. Договор действует до его прекращения в порядке, установленном законодательством Российской Федерации.'), firstLine: 360, after: 160),
      _heading('2. ПРАВА И ОБЯЗАННОСТИ РАБОТНИКА'),
      _paragraph(_run('2.1. Работник имеет права, предусмотренные Трудовым кодексом Российской Федерации, включая право на обусловленную договором работу, безопасное рабочее место, отдых, своевременную выплату заработной платы и обязательное социальное страхование.'), firstLine: 360, after: 100),
      _paragraph(_run('2.2. Работник обязан добросовестно исполнять трудовые обязанности, выполнять законные распоряжения руководителей, соблюдать правила внутреннего трудового распорядка, требования охраны труда, бережно относиться к имуществу Работодателя и не разглашать охраняемую законом и договором информацию.'), firstLine: 360, after: 160),
      _heading('3. ПРАВА И ОБЯЗАННОСТИ РАБОТОДАТЕЛЯ'),
      _paragraph(_run('3.1. Работодатель вправе требовать исполнения трудовых обязанностей, поощрять Работника и привлекать его к ответственности в порядке, установленном законодательством.'), firstLine: 360, after: 100),
      _paragraph(_run('3.2. Работодатель обязан предоставить работу, обеспечить безопасные условия и необходимые средства, вести учёт рабочего времени, выплачивать заработную плату в полном размере и соблюдать требования законодательства о труде и персональных данных.'), firstLine: 360, after: 160),
      _heading('4. РЕЖИМ ТРУДА И ОТДЫХА'),
      _paragraph(_run('4.1. Работнику устанавливается следующий режим: $schedule. Конкретное распределение рабочего времени и дней отдыха определяется графиком и локальными актами с соблюдением требований законодательства.'), firstLine: 360, after: 160),
      _heading('5. УСЛОВИЯ ОПЛАТЫ ТРУДА'),
      _paragraph(_run('5.1. Условия оплаты труда: $salary. Сроки и порядок выплаты определяются законодательством, локальными актами и соглашениями сторон.'), firstLine: 360, after: 100),
      _paragraph(_run('5.2. Компенсационные и стимулирующие выплаты начисляются при наличии оснований и в порядке, установленном Работодателем и законодательством.'), firstLine: 360, after: 160),
      _heading('6. ОТВЕТСТВЕННОСТЬ И РАЗРЕШЕНИЕ СПОРОВ'),
      _paragraph(_run('6.1. Стороны несут ответственность в соответствии с Трудовым кодексом Российской Федерации и иными нормативными актами. Споры разрешаются путём переговоров, а при недостижении соглашения — в установленном законом порядке.'), firstLine: 360, after: 160),
      _heading('7. ЗАКЛЮЧИТЕЛЬНЫЕ ПОЛОЖЕНИЯ'),
      _paragraph(_run('7.1. Договор составлен в двух экземплярах, имеющих одинаковую юридическую силу, по одному для каждой стороны. Изменения оформляются письменным соглашением.'), firstLine: 360, after: 180),
      _heading('8. РЕКВИЗИТЫ И ПОДПИСИ СТОРОН'),
      _detailsTable(<(String, String)>[
        ('Работодатель', '$employerName\n$employerDetails'),
        ('Работник', '$employee\nДата рождения: $birthDate\nМесто рождения: $birthPlace\nПаспорт: $passportSeries № $passportNumber\nВыдан: $passportIssuedBy, $passportIssuedDate\nКод подразделения: $departmentCode\nАдрес регистрации: $registrationAddress\nТелефон: $phone\nИНН: $inn\nСНИЛС: $snils'),
      ]),
      _blank(),
      _borderlessSignatureTable(
        left: 'Работодатель: ________________',
        right: 'Работник: ________________ / $employee /',
      ),
      _paragraph(_run('Работник получил один экземпляр договора: ________________ / $employee /', size: 20), after: 0),
      '<w:p/>',
      _section(pageWidth: 11906, pageHeight: 16838),
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
    final lines = value.split('\n');
    final paragraphs = lines
        .map((line) => _paragraph(_run(line, bold: labelCell, size: labelCell ? 22 : null)))
        .join();
    return '<w:tc><w:tcPr><w:tcW w:w="${labelCell ? 3685 : 5953}" '
        'w:type="dxa"/>$borders'
        '${labelCell ? '<w:shd w:val="clear" w:color="auto" w:fill="F2F2F2"/>' : ''}'
        '</w:tcPr>$paragraphs</w:tc>';
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
