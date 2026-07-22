import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('published tasks are archived instead of physically deleted', () {
    final migration = source(
      'supabase/migrations/20260722183000_task_governance_recycle_bin.sql',
    );
    final compatibility = source(
      'supabase/migrations/20260722183500_task_soft_delete_compatibility.sql',
    );

    expect(migration, contains('add column if not exists deleted_at'));
    expect(migration, contains('create table if not exists public.task_action_audit'));
    expect(migration, contains('create or replace function public.restore_task'));
    expect(
      migration,
      contains('create or replace function public.get_task_governance_center'),
    );
    expect(migration, contains('and deleted_at is null'));

    expect(compatibility, contains('if old.is_draft then'));
    expect(compatibility, contains('return old;'));
    expect(compatibility, contains('update public.tasks'));
    expect(compatibility, contains('return null;'));
  });

  test('task audit is not directly accessible from the client', () {
    final migration = source(
      'supabase/migrations/20260722184000_task_action_audit_deny_direct_access.sql',
    );

    expect(migration, contains('task_action_audit_no_direct_access'));
    expect(migration, contains('using (false)'));
    expect(migration, contains('with check (false)'));
  });

  test('developer navigation exposes task control center', () {
    final navigation = source(
      'lib/features/developer/presentation/developer_main_screen.dart',
    );
    final screen = source(
      'lib/features/developer/presentation/task_governance_screen.dart',
    );

    expect(navigation, contains('static const int pageCount = 5;'));
    expect(navigation, contains('const TaskGovernanceScreen()'));
    expect(navigation, contains("label: 'Контроль'"));

    expect(screen, contains("title: 'Контроль задач'"));
    expect(screen, contains("title: 'Корзина задач'"));
    expect(screen, contains("title: 'Журнал действий'"));
    expect(screen, contains("const Text('Восстановить')"));
  });

  test('delete confirmation explains recovery and retained data', () {
    final actions = source(
      'lib/screens/task_details/task_details_actions.dart',
    );

    expect(actions, contains('Переместить задачу в корзину?'));
    expect(actions, contains('исполнители, фотографии и связь с целью сохранятся'));
    expect(actions, contains("child: const Text('В корзину')"));
    expect(actions, isNot(contains('Задача, исполнители и фото будут удалены.')));
  });
}
