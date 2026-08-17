import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lawyer employee dossier exposes complete personal and legal sections', () {
    final source = File(
      'lib/features/legal/presentation/legal_employee_dossier_screen.dart',
    ).readAsStringSync();

    for (final section in <String>[
      'Личные данные',
      'Работа и контакты',
      'Паспорт и рождение',
      'Идентификаторы и адреса',
      'Банковские реквизиты',
      'Договоры',
      'Заявления и согласия',
      'Личные документы',
      'Акты и объяснительные',
      'Взыскания',
      'Юридические дела',
      'Прочие документы',
    ]) {
      expect(source, contains(section));
    }

    for (final key in <String>[
      'birth_date',
      'birth_place',
      'passport_series',
      'passport_number',
      'passport_issued_by',
      'passport_issued_date',
      'passport_department_code',
      'snils',
      'inn',
      'registration_address',
      'living_address',
      'bank_name',
      'bank_card',
      'bank_account',
      'bank_bik',
      'bank_corr_account',
      'bank_inn',
      'bank_kpp',
      'bank_okpo',
      'bank_ogrn',
      'bank_swift',
      'contract_number',
      'employment_start_date',
      'dismissal_date',
      'citizenship',
      'consent_personal_data',
    ]) {
      expect(source, contains("'$key'"));
    }
  });

  test('dossier repository is backed by dedicated secured RPCs', () {
    final source = File(
      'lib/features/legal/data/legal_employee_dossier_repository.dart',
    ).readAsStringSync();
    expect(source, contains("rpc(\n      'legal_employee_dossier'"));
    expect(source, contains("'legal_employee_dossier_documents'"));
  });

  test('personal data migration keeps tenant, permission and audit boundaries', () {
    final sql = File(
      'supabase/migrations/20260817074529_legal_employee_complete_dossier.sql',
    ).readAsStringSync();

    expect(sql, contains("'legal.personal_data.view'"));
    expect(sql, contains("('lawyer', 'legal.personal_data.view')"));
    expect(sql, contains('security definer'));
    expect(sql, contains('public.current_user_company_id()'));
    expect(sql, contains('public.personal_data_access_log'));
    expect(sql, contains("'legal_employee_dossier'"));
    expect(sql, contains('public.employee_private_data'));
    expect(sql, contains('public.recruitment_applications'));
    expect(sql, contains('public.recruitment_documents'));
    expect(sql, contains('public.recruitment_onboarding_forms'));
    expect(sql, contains('public.employee_document_files'));
    expect(sql, contains('public.legal_documents'));
    expect(sql, contains('(гпх|gph|civil|service|оказан.*услуг|подряд'));
    expect(sql, contains("'application_consent'"));
    expect(sql, contains("'personal_document'"));
    expect(sql, contains("'act_explanation'"));
    expect(sql, contains('ra.employee_id is not null'));
  });

  test('global HR templates are recognized for employee forms', () {
    final sql = File(
      'supabase/migrations/20260817075400_legal_employee_dossier_global_templates.sql',
    ).readAsStringSync();
    expect(sql, contains('dt.company_id is null or dt.company_id = edf.company_id'));
    expect(sql, contains('t.company_id is null or t.company_id = f.company_id'));
    expect(sql, contains('employment_contract'));
    expect(sql, contains('(гпх|gph|civil|service|оказан.*услуг|подряд'));
  });

  test('employee dossier is the only employee card in lawyer base', () {
    final workspace = File(
      'lib/features/legal/presentation/legal_workspace_screen.dart',
    ).readAsStringSync();
    expect(workspace, contains('LegalEmployeeDossierScreen(employee: item)'));
    expect(workspace, isNot(contains('class _EmployeeDossierScreen')));
  });

  test('adding a legal document from dossier preselects employee and object', () {
    final editor = File(
      'lib/features/legal/presentation/legal_document_editor_part.dart',
    ).readAsStringSync();
    expect(editor, contains('final String? initialEmployeeId;'));
    expect(editor, contains('final String? initialObjectId;'));
    expect(editor, contains('employeeId = widget.initialEmployeeId;'));
    expect(editor, contains('objectId = widget.initialObjectId'));
  });
}
