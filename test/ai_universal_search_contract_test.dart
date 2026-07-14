import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('chat routes free search to ai-search and keeps structured scenarios', () {
    final repository = source(
      'lib/features/ai/data/ai_assistant_repository.dart',
    );

    expect(repository, contains("'ai-assistant'"));
    expect(repository, contains("'ai-search'"));
    expect(repository, contains('timesheetOrSummary'));
    expect(repository, contains('documentAction && documentType'));
  });

  test('universal search covers application data sources', () {
    final index = source('supabase/functions/ai-search/index.ts');
    final core = source('supabase/functions/ai-search/core_search.ts');
    final extra = source('supabase/functions/ai-search/extra_search.ts');
    final admin = source('supabase/functions/ai-search/admin_search.ts');

    expect(index, contains('.from("employees")'));
    expect(index, contains('.from("objects")'));
    expect(core, contains('.from("tasks")'));
    expect(core, contains('.from("attendance")'));
    expect(extra, contains('.from("employee_comments")'));
    expect(extra, contains('.from("app_notifications")'));
    expect(extra, contains('.from("task_assignees")'));
    expect(extra, contains('.from("task_photos")'));
    expect(admin, contains('.from("payments")'));
    expect(admin, contains('.from("payment_receipts")'));
    expect(admin, contains('.from("company_memberships")'));
    expect(admin, contains('.from("companies")'));
    expect(admin, contains('.from("company_invitations")'));
    expect(admin, contains('.from("company_plan_requests")'));
  });

  test('search understands periods and natural Russian queries', () {
    final period = source('supabase/functions/ai-search/period.ts');
    final index = source('supabase/functions/ai-search/index.ts');

    expect(period, contains('весь доступный период'));
    expect(period, contains('вчера'));
    expect(period, contains('прошл'));
    expect(period, contains('20\\d{2}'));
    expect(index, contains('bestMatches(objects'));
    expect(index, contains('findEmployees(prompt'));
    expect(index, contains('Невыполненные задачи в Мурманске'));
    expect(index, contains('Выплаты Филимонову за июнь'));
  });

  test('search stays company scoped read only and protects private data', () {
    final files = <String>[
      'supabase/functions/ai-search/index.ts',
      'supabase/functions/ai-search/core_search.ts',
      'supabase/functions/ai-search/extra_search.ts',
      'supabase/functions/ai-search/admin_search.ts',
    ].map(source).join('\n');

    expect(files, contains('auth.getUser()'));
    expect(files, contains('.eq("company_id", companyId)'));
    expect(files, contains('Прорабу не назначен объект'));
    expect(files, contains('только администратору'));
    expect(files, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
    expect(files, isNot(contains('employee_private_data')));
    expect(files, isNot(contains('push_device_tokens')));
    expect(files, isNot(contains('daily_rate')));
    expect(files, isNot(contains('.insert(')));
    expect(files, isNot(contains('.update(')));
    expect(files, isNot(contains('.upsert(')));
    expect(files, isNot(contains('.delete(')));
  });
}
