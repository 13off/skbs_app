import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('сервер определяет документ без чтения закрытых реквизитов', () {
    final edge = source('supabase/functions/ai-document-draft/index.ts');

    expect(edge, contains('auth.getUser()'));
    expect(edge, contains('.from("user_profiles")'));
    expect(edge, contains('.from("company_memberships")'));
    expect(edge, contains('.from("employees")'));
    expect(edge, contains('type: "prepare_document"'));
    expect(edge, contains('confirmation_required: true'));
    expect(edge, contains('Кадровые документы доступны администратору или HR'));
    expect(edge, isNot(contains('employee_private_data')));
    expect(edge, isNot(contains('passport_')));
    expect(edge, isNot(contains('bank_account')));
    expect(edge, isNot(contains('bank_card')));
    expect(edge, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
    expect(edge, isNot(contains('.insert(')));
    expect(edge, isNot(contains('.update(')));
    expect(edge, isNot(contains('.upsert(')));
    expect(edge, isNot(contains('.delete(')));
  });

  test('закрытые данные подставляются только локально через существующий RLS', () {
    final screen = source(
      'lib/features/ai/presentation/ai_document_draft_screen.dart',
    );
    final builder = source(
      'lib/features/ai/documents/ai_document_draft.dart',
    );

    expect(screen, contains('EmployeeRepository.fetchEmployees('));
    expect(screen, contains('EmployeePrivateDataRepository.fetchByEmployeeId('));
    expect(screen, contains('widget.profile.isAdmin || widget.profile.isHr'));
    expect(screen, contains('CompanyRepository.fetchCompany('));
    expect(screen, contains('AiDocumentDraftBuilder.build('));
    expect(builder, contains('EmployeePrivateData? privateData'));
    expect(builder, contains("'[указать \$field]'"));
    expect(builder, contains('ЧЕРНОВИК — ТРЕБУЕТ ПРОВЕРКИ'));
  });

  test('предпросмотр редактируется и не отправляет документ автоматически', () {
    final screen = source(
      'lib/features/ai/presentation/ai_document_draft_screen.dart',
    );
    final download = source(
      'lib/features/ai/documents/ai_document_download_service.dart',
    );
    final assistant = source(
      'lib/features/ai/presentation/ai_assistant_action_screen.dart',
    );

    expect(screen, contains('TextEditingController titleController'));
    expect(screen, contains('TextEditingController bodyController'));
    expect(screen, contains("labelText: 'Текст документа'"));
    expect(screen, contains("label: const Text('Скачать Word')"));
    expect(screen, contains("label: const Text('Готово')"));
    expect(screen, contains('Navigator.pop(context, true)'));
    expect(download, contains('application/msword'));
    expect(download, contains("..download = '\$fileBaseName.doc'"));

    expect(assistant, contains("case 'prepare_document':"));
    expect(assistant, contains('AiDocumentDraftScreen('));
    expect(assistant, contains('if (!mounted || completed != true) return;'));
    expect(assistant, contains("'Документ скачан'"));

    final combined = '$screen\n$download\n$assistant';
    expect(combined, isNot(contains('sendEmail(')));
    expect(combined, isNot(contains('.insert(')));
    expect(combined, isNot(contains('.upsert(')));
  });
}
