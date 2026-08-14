import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('восстановленный сотрудник возвращается в активный список', () {
    final migration = File(
      'supabase/migrations/20260814162000_atomic_archive_batches.sql',
    ).readAsStringSync();

    expect(migration, contains('set is_active = true'));
    expect(migration, contains('archived_at = null'));
    expect(migration, contains('bulk_restore_archived_employees'));
  });

  test('автор комментария устанавливается только сервером', () {
    final repository = File(
      'lib/data/employee_comments_repository.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260814160000_secure_employee_comment_actor.sql',
    ).readAsStringSync();

    expect(repository, isNot(contains("'created_by': 'Илья'")));
    expect(repository, contains('created_by_user_id'));
    expect(migration, contains('v_user_id uuid := auth.uid()'));
    expect(migration, contains('new.created_by_user_id := v_user_id'));
    expect(migration, contains('new.created_by := old.created_by'));
  });

  test('пакет задач создаётся одной серверной транзакцией со связями', () {
    final migration = File(
      'supabase/migrations/20260814161000_atomic_task_and_recruitment_batches.sql',
    ).readAsStringSync();

    expect(migration, contains('create_task_batch'));
    expect(migration, contains('jsonb_array_elements(p_tasks)'));
    expect(migration, contains('insert into public.task_assignees'));
    expect(migration, contains('insert into public.task_milestone_links'));
    expect(migration, contains('task_can_create_for_user'));
  });

  test('окончательное удаление объекта не стирает связанные модули', () {
    final migration = File(
      'supabase/migrations/20260814162000_atomic_archive_batches.sql',
    ).readAsStringSync();

    expect(migration, contains('к нему привязаны контрольные точки'));
    expect(migration, contains('к нему привязаны кандидаты'));
    expect(migration, contains('к нему привязаны заявки снабжения'));
    expect(migration, contains("appstroy.force_permanent_task_delete"));
  });
}
