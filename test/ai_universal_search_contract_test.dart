import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('chat routes free search to ai-search and keeps structured scenarios', () {
    final repository = source(
      'lib/features/ai/data/ai_assistant_repository.dart',
    );

    expect(repository, contains("? 'ai-assistant'"));
    expect(repository, contains(": 'ai-search'"));
    expect(repository, contains('табел|смен|выход|отработ|сводк'));
  });

  test('universal search covers core company data', () {
    final index = source('supabase/functions/ai-search/index.ts');
    final core = source('supabase/functions/ai-search/core_search.ts');
    final admin = source('supabase/functions/ai-search/admin_search.ts');

    expect(index, contains('.from("employees")'));
    expect(index, contains('.from("objects")'));
    expect(core, contains('.from("tasks")'));
    expect(core, contains('.from("attendance")'));
    expect(admin, contains('.from("payments")'));
    expect(admin, contains('.from("payment_receipts")'));
    expect(admin, contains('.from("company_memberships")'));
    expect(admin, contains('.from("companies")'));
    expect(admin, contains('.from("company_invitations")'));
  });

  test('search stays scoped, read only and protects sensitive fields', () {
    final files = <String>[
      'supabase/functions/ai-search/index.ts',
      'supabase/functions/ai-search/core_search.ts',
      'supabase/functions/ai-search/admin_search.ts',
    ].map(source).join('\n');

    expect(files, contains('auth.getUser()'));
    expect(files, contains('.eq("company_id", companyId)'));
    expect(files, contains('Прорабу не назначен объект'));
    expect(files, contains('только администратору'));
    expect(files, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
    expect(files, isNot(contains('phone,')));
    expect(files, isNot(contains('daily_rate')));
    expect(files, isNot(contains('.insert(')));
    expect(files, isNot(contains('.update(')));
    expect(files, isNot(contains('.upsert(')));
    expect(files, isNot(contains('.delete(')));
  });
}
