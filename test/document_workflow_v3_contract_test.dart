import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/documents/models/document_onboarding.dart';

void main() {
  test('document onboarding keeps the required thirteen-step order', () {
    expect(DocumentOnboardingSteps.ordered, hasLength(13));
    expect(DocumentOnboardingSteps.ordered.first, DocumentOnboardingSteps.sourceFiles);
    expect(DocumentOnboardingSteps.ordered.last, DocumentOnboardingSteps.completion);
    expect(DocumentOnboardingSteps.ordered.toSet(), hasLength(13));
  });

  test('workflow reuses versioned document templates', () {
    final migration = File(
      'supabase/migrations/20260802220000_document_workflow_v3_foundation.sql',
    ).readAsStringSync();
    expect(migration, contains('references public.document_templates'));
    expect(migration, contains('references public.document_template_versions'));
    expect(migration, isNot(contains('create table if not exists public.document_template ')));
  });

  test('workflow is company scoped and non destructive', () {
    final migration = File(
      'supabase/migrations/20260802220000_document_workflow_v3_foundation.sql',
    ).readAsStringSync();
    expect(migration, contains('company_id uuid'));
    expect(migration, contains('is_enabled boolean not null default false'));
    expect(migration.toLowerCase(), isNot(contains('drop table')));
    expect(migration.toLowerCase(), isNot(contains('truncate table')));
  });

  test('completion validates signed files and final scans', () {
    final migration = File(
      'supabase/migrations/20260802223000_document_workflow_v3_runtime.sql',
    ).readAsStringSync();
    expect(migration, contains("f.file_kind = 'signed'"));
    expect(migration, contains("f.file_kind = 'final_scan'"));
    expect(migration, contains("f.verification_status = 'accepted'"));
  });

  test('employee documents use a private storage bucket', () {
    final migration = File(
      'supabase/migrations/20260802223000_document_workflow_v3_runtime.sql',
    ).readAsStringSync();
    expect(
      migration,
      contains("values ('employee-documents', 'employee-documents', false"),
    );
  });
}
