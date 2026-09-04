import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('task is queued locally before any network attempt', () {
    final create = source('lib/screens/add_task_screen.dart');
    final service = source('lib/data/offline_task_create_service.dart');

    expect(create, contains('OfflineTaskCreateService.queueTask('));
    expect(create, isNot(contains('OfflineTaskCreateService.shouldQueueImmediately')));
    expect(service, isNot(contains('navigator.onLine')));
    expect(service, contains("kind: 'task.create'"));
    expect(service, contains("'source': 'local_first_task_create'"));
    expect(service, contains('unawaited(OfflineSyncService.flush())'));
  });

  test('queued task keeps assignee and photo metadata locally', () {
    final service = source('lib/data/offline_task_create_service.dart');

    expect(service, contains("'task_assignee_ids::\$taskId'"));
    expect(service, contains("'task_photos::\$taskId'"));
    expect(service, contains("'storage_path': ''"));
    expect(service, contains("photoStage: 'before'"));
  });

  test('waiting indicator does not call server contact a completed sync', () {
    final status = source('lib/widgets/offline_sync_banner.dart');

    expect(status, contains('Сервер ещё не подтвердил эти изменения'));
    expect(status, contains('Последняя успешная связь с сервером'));
    expect(status, contains('_flushAndRefresh()'));
    expect(status, contains("'source': 'offline_flush'"));
  });

  test('database replay starts final offline task as safe draft', () {
    final migration = source(
      'supabase/migrations/20260904195500_allow_offline_task_upsert_via_safe_draft.sql',
    );

    expect(migration, contains('if not coalesce(new.is_draft, false) then'));
    expect(migration, contains('new.is_draft := true;'));
    expect(
      migration,
      isNot(contains("raise exception 'Новая задача должна быть создана через безопасный черновик'")),
    );
  });
}
