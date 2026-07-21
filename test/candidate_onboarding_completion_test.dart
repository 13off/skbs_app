import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/documents/data/exact_docx_service.dart';

void main() {
  String documentXml(ExactDocxResult result) {
    final archive = ZipDecoder().decodeBytes(result.bytes);
    final file = archive.findFile('word/document.xml');
    expect(file, isNotNull);
    return utf8.decode(file!.content as List<int>);
  }

  test('согласие собирается локально и не выдумывает реквизиты', () {
    final result = ExactDocxService.build(
      templateCode: 'personal_data_consent',
      fileBaseName: 'Согласие Иванов',
      values: const <String, String>{
        'employee_full_name': 'Иванов Иван Иванович',
        'employee_short_name': 'Иванов И. И.',
        'employee_phone': '+7 999 000-00-00',
        'employer_name': 'ООО «СКБС»',
        'document_date': '21.07.2026',
      },
    );

    final xml = documentXml(result);
    expect(xml, contains('Иванов Иван Иванович'));
    expect(xml, contains('Федерального закона'));
    expect(xml, contains('________________'));
    expect(result.missingFields, contains('passport_series'));
    expect(result.missingFields, contains('employer_address'));
  });

  test('трудовой договор содержит основные разделы и реквизиты', () {
    final result = ExactDocxService.build(
      templateCode: 'employment_contract',
      fileBaseName: 'Договор Иванов',
      values: const <String, String>{
        'contract_number': '13/2026',
        'document_date': '21.07.2026',
        'contract_city': 'Мурманск',
        'employer_name': 'ООО «СКБС»',
        'employer_representative': 'генерального директора Ермолиной О.Б.',
        'employer_basis': 'Устава',
        'employee_full_name': 'Иванов Иван Иванович',
        'employee_position': 'Бетонщик',
        'work_address': 'Объект Мурманск',
        'employment_date': '01.08.2026',
        'work_schedule': 'по утверждённому графику',
        'salary_terms': 'согласно штатному расписанию',
        'employee_birth_date': '01.01.1990',
        'employee_birth_place': 'г. Пермь',
        'passport_series': '5700',
        'passport_number': '123456',
        'passport_issued_by': 'ГУ МВД России',
        'passport_issued_date': '01.01.2010',
        'passport_department_code': '590-001',
        'registration_address': 'г. Пермь',
        'employee_phone': '+7 999 000-00-00',
        'employee_inn': '590000000000',
        'employee_snils': '000-000-000 00',
        'employer_details': 'Реквизиты работодателя',
      },
    );

    expect(result.missingFields, isEmpty);
    final xml = documentXml(result);
    expect(xml, contains('ТРУДОВОЙ ДОГОВОР'));
    expect(xml, contains('ПРЕДМЕТ ДОГОВОРА'));
    expect(xml, contains('УСЛОВИЯ ОПЛАТЫ ТРУДА'));
    expect(xml, contains('Иванов Иван Иванович'));
    expect(xml, contains('Объект Мурманск'));
  });

  test('исходники согласия и договора зафиксированы хешами', () {
    expect(
      ExactDocxService.personalDataConsent.originalSha256,
      '20405bf4424884ebad315d6b3d74ee5d7f62dc4ee306056e1a3bfc3fb79b079e',
    );
    expect(
      ExactDocxService.employmentContract.originalSha256,
      '9d0fdbb32df89d846f9ccda2bda14711bba6ac6441319dabe3b9bca12c969d4d',
    );
    expect(ExactDocxService.personalDataConsent.legalReviewRequired, isTrue);
    expect(ExactDocxService.employmentContract.legalReviewRequired, isTrue);
  });

  test('переход кандидата в сотрудника остаётся подтверждаемым', () {
    final screen = File(
      'lib/features/ai/presentation/ai_operational_report_screen.dart',
    ).readAsStringSync();

    expect(screen, contains('AiEmployeeDraftScreen'));
    expect(screen, contains("status: 'hired'"));
    expect(screen, contains('Дубликаты по ФИО'));
    expect(screen, contains("action.boolean('consent_personal_data')"));
    expect(screen, isNot(contains(".from('employees').insert")));
  });

  test('генератор DOCX не содержит браузерного API', () {
    final service = File(
      'lib/features/documents/data/exact_docx_service.dart',
    ).readAsStringSync();

    expect(service, isNot(contains('universal_html')));
    expect(service, isNot(contains('AnchorElement')));
  });
}
