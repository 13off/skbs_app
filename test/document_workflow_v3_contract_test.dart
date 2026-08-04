import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/documents/models/document_onboarding.dart';

void main() {
  late String foundation;
  late String runtime;

  setUpAll(() {
    foundation = File(
      'supabase/migrations/20260802220000_document_workflow_v3_foundation.sql',
    ).readAsStringSync();
    runtime = File(
      'supabase/migrations/20260802223000_document_workflow_v3_runtime.sql',
    ).readAsStringSync();
  });

  test('document onboarding keeps the required thirteen-step order', () {
    expect(DocumentOnboardingSteps.ordered, hasLength(13));
    expect(
      DocumentOnboardingSteps.ordered.first,
      DocumentOnboardingSteps.sourceFiles,
    );
    expect(
      DocumentOnboardingSteps.ordered.last,
      DocumentOnboardingSteps.completion,
    );
    expect(DocumentOnboardingSteps.ordered.toSet(), hasLength(13));
  });

  test('workflow reuses existing versioned templates and recruitment data', () {
    expect(foundation, contains('references public.document_templates'));
    expect(
      foundation,
      contains('references public.document_template_versions'),
    );
    expect(foundation, contains('references public.recruitment_applications'));
    expect(foundation, contains('references public.recruitment_documents'));
    expect(
      foundation,
      isNot(contains('create table if not exists public.document_template ')),
    );
  });

  test('workflow is company scoped, permission based and non destructive', () {
    expect(foundation, contains('company_id uuid'));
    expect(foundation, contains('is_enabled boolean not null default false'));
    expect(foundation, contains('documents.workflow.view'));
    expect(foundation, contains('documents.onboarding.verify'));
    expect(foundation, contains('current_user_has_permission'));
    expect(foundation.toLowerCase(), isNot(contains('drop table')));
    expect(foundation.toLowerCase(), isNot(contains('truncate table')));
  });

  test(
    'runtime uses atomic server transitions instead of client-only checks',
    () {
      expect(runtime, contains('create_document_onboarding'));
      expect(runtime, contains('advance_document_onboarding'));
      expect(runtime, contains('complete_document_onboarding'));
      expect(runtime, contains('verify_employee_document_file'));
      expect(runtime, contains('document_onboarding_blockers'));
      expect(runtime, contains('security definer'));
    },
  );

  test('completion requires accepted signed documents and final scans', () {
    expect(runtime, contains("file_kind = 'signed'"));
    expect(runtime, contains("file_kind = 'final_scan'"));
    expect(runtime, contains("verification_status = 'accepted'"));
    expect(runtime, contains('hr_confirmed'));
  });

  test('employee documents remain private and use company-scoped paths', () {
    expect(runtime, contains("'employee-documents'"));
    expect(runtime, contains('public, file_size_limit'));
    expect(runtime, contains('false,'));
    expect(runtime, contains('document_workflow_files_select'));
    expect(runtime, contains('storage.foldername(name)'));
    expect(runtime, contains('current_user_company_id'));
  });

  test('audit writes are append-only through checked RPC functions', () {
    expect(foundation, contains('grant select on public.document_audit_log'));
    expect(
      foundation,
      isNot(contains('grant select, insert on public.document_audit_log')),
    );
    expect(runtime, contains('record_document_workflow_audit'));
  });
}
