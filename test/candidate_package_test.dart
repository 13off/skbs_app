import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/ai/models/ai_assistant_result.dart';
import 'package:skbs_app/features/recruitment/data/candidate_package_archive.dart';

void main() {
  const action = AiAssistantAction(
    id: 'candidate-package-test',
    type: 'prepare_candidate_documents',
    title: 'Пакет кандидата',
    buttonLabel: 'Открыть пакет',
    confirmationRequired: true,
    payload: <String, dynamic>{
      'application_id': 'application-1',
      'full_name': 'Иванов Иван Иванович',
      'phone': '+7 999 000-00-00',
      'citizenship': 'РФ',
      'position_title': 'Бетонщик',
      'status': 'documents',
      'ready_date': '2026-08-01',
      'consent_personal_data': true,
      'missing_documents': <String>['inn'],
      'date': '2026-07-21',
    },
  );

  test('ZIP содержит заполненное заявление, манифест и полученные файлы', () {
    final result = CandidatePackageArchive.build(
      action: action,
      generatedAt: DateTime(2026, 7, 21, 10, 30),
      warnings: const <String>[],
      attachments: <CandidatePackageAttachment>[
        CandidatePackageAttachment(
          documentType: 'passport',
          fileName: 'passport.pdf',
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
        ),
        CandidatePackageAttachment(
          documentType: 'snils',
          fileName: 'snils.jpg',
          bytes: Uint8List.fromList(<int>[4, 5, 6]),
        ),
      ],
    );

    expect(result.fileName, 'Пакет_Иванов_Иван_Иванович_20260721.zip');
    expect(result.includedFiles, 4);
    final archive = ZipDecoder().decodeBytes(result.bytes);
    final paths = archive.files.map((file) => file.name).toList();
    expect(paths, contains('00_ПРОВЕРИТЬ_ПЕРЕД_ПЕЧАТЬЮ.txt'));
    expect(
      paths.any((path) => path.startsWith(
        '01_Сформированные_формы/Заявление_на_работу_',
      )),
      isTrue,
    );
    expect(
      paths,
      contains('02_Полученные_документы/01_passport.pdf'),
    );
    expect(
      paths,
      contains('02_Полученные_документы/02_snils.jpg'),
    );

    final manifest = archive.findFile('00_ПРОВЕРИТЬ_ПЕРЕД_ПЕЧАТЬЮ.txt');
    final manifestText = utf8.decode(manifest!.content as List<int>);
    expect(manifestText, contains('Иванов Иван Иванович'));
    expect(manifestText, contains('Дата готовности: 2026-08-01'));
    expect(manifestText, contains('— ИНН'));
    expect(manifestText, contains('не добавлено без банковских реквизитов'));
    expect(manifestText, contains('Документы не подписаны и не отправлены'));
  });

  test('вложенное заявление заполнено данными кандидата', () {
    final result = CandidatePackageArchive.build(
      action: action,
      generatedAt: DateTime(2026, 7, 21),
      warnings: const <String>[],
      attachments: const <CandidatePackageAttachment>[],
    );
    final package = ZipDecoder().decodeBytes(result.bytes);
    final docx = package.files.firstWhere(
      (file) => file.name.endsWith('.docx'),
    );
    final nested = ZipDecoder().decodeBytes(docx.content as List<int>);
    final document = nested.findFile('word/document.xml');
    final xml = utf8.decode(document!.content as List<int>);

    expect(xml, contains('Иванов Иван Иванович'));
    expect(xml, contains('Бетонщик'));
    expect(xml, contains('01.08.2026'));
    expect(xml, isNot(contains('{{')));
  });

  test('пакет не выдумывает зарплатную форму без реквизитов', () {
    final result = CandidatePackageArchive.build(
      action: action,
      generatedAt: DateTime(2026, 7, 21),
      warnings: const <String>[],
      attachments: const <CandidatePackageAttachment>[],
    );
    final paths = ZipDecoder()
        .decodeBytes(result.bytes)
        .files
        .map((file) => file.name)
        .toList();

    expect(paths.any((path) => path.contains('перечислен')), isFalse);
    expect(
      result.warnings,
      contains(
        'Заявление на перечисление зарплаты не включено без проверенных банковских реквизитов кандидата.',
      ),
    );
  });

  test('файлы кандидата читаются только клиентом после RLS', () {
    final repository = File(
      'lib/features/recruitment/data/candidate_document_repository.dart',
    ).readAsStringSync();
    final service = File(
      'lib/features/recruitment/data/candidate_package_service.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/ai/presentation/ai_operational_report_screen.dart',
    ).readAsStringSync();
    final edge = <String>[
      File('supabase/functions/ai-operational-draft/shared.ts').readAsStringSync(),
      File('supabase/functions/ai-operational-draft/report_actions.ts')
          .readAsStringSync(),
    ].join('\n');

    expect(repository, contains(".from('recruitment_documents')"));
    expect(repository, contains('.storage.from(file.bucket).download'));
    expect(repository, contains(".eq('is_test_copy', false)"));
    expect(service, contains('CandidateDocumentRepository.download'));
    expect(screen, contains("'Скачать пакет кандидата ZIP'"));
    expect(screen, contains('ZIP собирается локально'));
    expect(edge, contains('ready_date'));
    expect(edge, isNot(contains('storage_path')));
    expect(edge, isNot(contains('storage_bucket')));
    expect(edge, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
  });
}
