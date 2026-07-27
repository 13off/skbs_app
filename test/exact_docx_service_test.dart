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

  test('заявление на работу собирается как настоящий DOCX', () {
    final result = ExactDocxService.build(
      templateCode: 'employment_application',
      fileBaseName: 'Иванов заявление',
      values: const <String, String>{
        'employee_full_name': 'Иванов Иван Иванович',
        'employee_short_name': 'Иванов И. И.',
        'employee_position': 'Бетонщик',
        'employment_date': '21.07.2026',
        'document_date': '21.07.2026',
      },
    );

    expect(result.fileName, 'Иванов_заявление.docx');
    expect(result.missingFields, isEmpty);
    final archive = ZipDecoder().decodeBytes(result.bytes);
    expect(archive.findFile('[Content_Types].xml'), isNotNull);
    expect(archive.findFile('_rels/.rels'), isNotNull);
    expect(archive.findFile('word/styles.xml'), isNotNull);
    final xml = documentXml(result);
    expect(xml, contains('Иванов Иван Иванович'));
    expect(xml, contains('Бетонщик'));
    expect(xml, contains('21.07.2026'));
    expect(xml, contains('Иванов И. И.'));
    expect(xml, isNot(contains('{{')));
  });

  test('банковская форма сохраняет таблицу и экранирует XML', () {
    final result = ExactDocxService.build(
      templateCode: 'salary_transfer_application',
      fileBaseName: 'зарплата',
      values: const <String, String>{
        'employee_full_name': 'Петров Пётр Петрович',
        'employee_short_name': 'Петров П. П.',
        'employee_position': 'Арматурщик & бетонщик',
        'bank_account': '40817810000000000001',
        'bank_name': 'АО <Банк>',
        'bank_bik': '044525225',
        'bank_corr_account': '30101810400000000225',
        'bank_inn': '7707083893',
        'bank_kpp': '773601001',
        'bank_okpo': '00032537',
        'bank_ogrn': '1027700132195',
        'bank_swift': 'SABRRUMM',
        'bank_address': 'Москва',
        'bank_office_address': 'Мурманск',
        'document_date': '21.07.2026',
      },
    );

    expect(result.missingFields, isEmpty);
    final xml = documentXml(result);
    expect(xml, contains('<w:tbl>'));
    expect(xml, contains('40817810000000000001'));
    expect(xml, contains('Арматурщик &amp; бетонщик'));
    expect(xml, contains('АО &lt;Банк&gt;'));
    expect(xml, isNot(contains('{{')));
  });

  test('неполные реквизиты не выдумываются', () {
    final result = ExactDocxService.build(
      templateCode: 'salary_transfer_application',
      fileBaseName: 'неполная форма',
      values: const <String, String>{
        'employee_full_name': 'Сотрудник',
      },
    );

    expect(result.missingFields, contains('bank_account'));
    expect(result.missingFields, contains('bank_bik'));
    expect(documentXml(result), contains('________________'));
  });

  test('закрытые данные остаются на клиенте', () {
    final screen = File(
      'lib/features/ai/presentation/ai_exact_document_screen.dart',
    ).readAsStringSync();
    final wrapper = File(
      'lib/features/ai/presentation/ai_document_template_screen.dart',
    ).readAsStringSync();

    expect(screen, contains('EmployeePrivateDataRepository.fetchByEmployeeId'));
    expect(screen, contains('ExactDocxService.build('));
    expect(screen, contains('Реквизиты подставляются локально'));
    expect(screen, isNot(contains('AiAssistantRepository')));
    expect(screen, isNot(contains('functions.invoke')));
    expect(screen, isNot(contains('.insert(')));
    expect(screen, isNot(contains('.update(')));
    expect(wrapper, contains("label: const Text('Заполнить оригинал DOCX')"));
    expect(wrapper, contains('AiDocumentDraftScreen('));
    expect(wrapper, contains("label: const Text('Исходная форма')"));
  });

  test('заполненный DOCX сохраняется на поддерживаемых платформах', () {
    final screen = File(
      'lib/features/ai/presentation/ai_exact_document_screen.dart',
    ).readAsStringSync();

    expect(
      screen,
      contains("import 'package:file_saver/file_saver.dart';"),
    );
    expect(screen, contains('await FileSaver.instance.saveFile'));
    expect(screen, contains('MimeType.microsoftWord'));
    expect(screen, contains("ext: 'docx'"));
    expect(
      screen,
      isNot(contains('ExactDocxService.download(result)')),
    );
  });

  test('исходные SHA-256 зафиксированы', () {
    expect(
      ExactDocxService.employmentApplication.originalSha256,
      '7a43d67c2235a07e718b86125ecc69474392bbd2855d7a09a212ccc3faa646f1',
    );
    expect(
      ExactDocxService.salaryTransferApplication.originalSha256,
      'f7501f5b8d6f170840b67c24d5cf3a33377a55cf9cb92eff1c17ce47ec1406a9',
    );
  });
}
