import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const coreMigrationPath =
      'supabase/migrations/20260904214445_accounting_workbench_core.sql';
  const storageMigrationPath =
      'supabase/migrations/20260904222500_accounting_workbench_files_and_directories.sql';
  const detailRepositoryPath =
      'lib/features/accounting/data/accounting_detail_repository.dart';

  test('accountant document and calendar writes stay company scoped', () {
    final core = File(coreMigrationPath).readAsStringSync();

    for (final table in <String>[
      'accounting_primary_documents',
      'accounting_document_files',
      'accounting_calendar_tasks',
    ]) {
      expect(core, contains("'$table'"));
    }

    expect(
      core,
      contains(
        'for update using (company_id = public.current_user_company_id()',
      ),
    );
    expect(
      core,
      contains(
        'with check (company_id = public.current_user_company_id()',
      ),
    );
    expect(core, contains("''accountant''::text"));
  });

  test('accounting document storage is private and company scoped', () {
    final storage = File(storageMigrationPath).readAsStringSync();

    expect(storage, contains("'accounting-documents'"));
    expect(storage, contains('accounting_documents_storage_select'));
    expect(storage, contains('accounting_documents_storage_insert'));
    expect(storage, contains('accounting_documents_storage_delete'));
    expect(
      storage,
      contains(
        '(storage.foldername(name))[1] = public.current_user_company_id()::text',
      ),
    );
    expect(
      storage,
      contains(
        'd.id::text = (storage.foldername(storage.objects.name))[2]',
      ),
    );
    expect(storage, contains("'accountant'::text"));
  });

  test('file replacement uses allowed insert plus delete lifecycle', () {
    final detailRepository = File(detailRepositoryPath).readAsStringSync();

    expect(detailRepository, contains('Future<void> replaceDocumentFile({'));
    expect(detailRepository, contains('await addDocumentFile('));
    expect(detailRepository, contains('await deleteDocumentFile(previous);'));
  });
}
