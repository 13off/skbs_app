import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('employee document functions use a shared visible feature gate', () {
    final gate = File(
      'lib/features/tools/presentation/document_tool_feature_gate.dart',
    ).readAsStringSync();
    final employeeView = File(
      'lib/screens/employee_details/employee_details_view.dart',
    ).readAsStringSync();
    final navigation = File(
      'lib/screens/employee_details/employee_details_navigation.dart',
    ).readAsStringSync();

    expect(gate, contains('class DocumentToolFeatureLock'));
    expect(gate, contains('class DocumentToolProtectedScreen'));
    expect(gate, contains("'document_tool_is_enabled'"));
    expect(gate, contains('ValueNotifier<int> revision'));
    expect(gate, contains('ColorFiltered('));
    expect(gate, contains('Icons.lock_rounded'));
    expect(gate, contains('Tooltip('));
    expect(gate, contains('SystemMouseCursors.forbidden'));
    expect(gate, contains('showModalBottomSheet<void>'));
    expect(gate, contains("'Подключите AppСтрой Трудоустройство'"));
    expect(gate, contains("'Открыть Инструменты'"));

    expect(employeeView, contains('DocumentToolAvailabilityBuilder('));
    expect(employeeView, contains('DocumentToolFeatureLock('));
    expect(employeeView, contains("title: 'Личные данные'"));
    expect(employeeView, contains("title: 'Документы'"));

    expect(navigation, contains('DocumentToolProtectedScreen('));
    expect(navigation, contains('EmployeePrivateDataScreen(employee: employee)'));
    expect(navigation, contains('EmployeeDocumentsScreen(employee: employee)'));
  });

  test('legacy HR generator uses approved AppStroy templates', () {
    final generator = File(
      'lib/data/hr_document_generator.dart',
    ).readAsStringSync();

    expect(generator, contains(".from('document_templates')"));
    expect(generator, contains(".from('document_template_versions')"));
    expect(generator, contains("case 'storage':"));
    expect(generator, contains("case 'asset':"));
    expect(generator, contains("case 'external':"));
    expect(generator, contains('HrDocumentGenerationException'));
    expect(
      generator,
      contains('Загрузите исходный DOCX в AppСтрой'),
    );
    expect(
      generator,
      isNot(
        contains('assets/templates/hr/employment_contract_template.docx'),
      ),
    );
  });

  test('database denies document reads and writes while tool is disabled', () {
    final migration = File(
      'supabase/migrations/20260803102000_document_tool_feature_gate.sql',
    ).readAsStringSync();

    expect(migration, contains('function public.document_tool_is_enabled'));
    expect(migration, contains('function public.require_document_tool_enabled'));
    expect(
      migration,
      contains("message = 'Подключите AppСтрой Трудоустройство'"),
    );
    expect(migration, contains("'employee_private_data'"));
    expect(migration, contains("'document_templates'"));
    expect(migration, contains("'employee_onboardings'"));
    expect(migration, contains("'employee_document_files'"));
    expect(migration, contains('employee_private_data_select_company_admin'));
    expect(migration, contains('employee_documents_select_company_admin'));
    expect(migration, contains('document_workflow_files_select'));
    expect(migration, contains('document_templates_storage_select'));
    expect(migration, contains('document_onboarding_blockers_unguarded'));
  });
}
