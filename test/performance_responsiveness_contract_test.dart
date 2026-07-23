import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('workspaces switch instantly and retain already opened tabs', () {
    final shell = source(
      'lib/features/shell/presentation/persistent_tab_shell.dart',
    );
    expect(shell, contains('currentIndex = index;'));
    expect(shell, contains('notifyListeners();'));
    expect(shell, contains('IndexedStack('));
    expect(shell, contains('_tabNavigators.putIfAbsent'));
    expect(shell, contains('TickerMode('));
    expect(shell, isNot(contains('animateToPage')));

    for (final path in <String>[
      'lib/features/recruitment/presentation/recruitment_main_screen.dart',
      'lib/features/accounting/presentation/accounting_main_screen.dart',
      'lib/features/developer/presentation/developer_main_screen.dart',
      'lib/features/legal/presentation/legal_main_screen.dart',
    ]) {
      final roleShell = source(path);
      expect(roleShell, contains('PersistentTabShell('));
      expect(roleShell, isNot(contains('PageView.builder')));
    }
  });

  test('tab taps do not write preferences twice', () {
    final navigation = source(
      'lib/widgets/professional_bottom_navigation.dart',
    );
    final handlerStart = navigation.indexOf('void handleSelected(int index)');
    final handlerEnd = navigation.indexOf('\n  Widget buildIcon', handlerStart);
    final handler = navigation.substring(handlerStart, handlerEnd);
    expect(handler, contains('widget.onSelected(index)'));
    expect(handler, isNot(contains('writeTabIndex')));
    expect(navigation, contains('final String? storageKey'));
  });

  test('profile and task opening do not wait on repeat network work', () {
    final profile = source('lib/screens/profile_screen.dart');
    final task = source('lib/screens/task_details_screen.dart');
    expect(profile, contains('class ProfileScreen extends StatefulWidget'));
    expect(profile, contains('Future<CompanySummary>? companyFuture'));
    expect(profile, contains('future: companyFuture'));
    expect(profile, contains('future: companiesFuture'));
    expect(task, contains('final previousChecklistItemFuture'));
    expect(task, contains('transitionDuration: Duration.zero'));
    expect(
      task.indexOf('Navigator.of(context).push<dynamic>'),
      lessThan(task.indexOf('await previousChecklistItemFuture')),
    );
  });

  test('data events and policy requests avoid synchronous fan-out', () {
    final sync = source('lib/data/app_data_sync.dart');
    final policy = source(
      'lib/features/developer/data/developer_policy_repository.dart',
    );
    expect(sync, contains('StreamController<AppDataChange>.broadcast()'));
    expect(sync, isNot(contains('broadcast(sync: true)')));
    expect(policy, contains('Map<String, Future<TaskPolicy>> _inFlight'));
    expect(policy, contains('final pending = _inFlight[key]'));
  });

  test('notification bell uses a lightweight unread RPC', () {
    final repository = source('lib/data/notification_repository.dart');
    final migration = source(
      'supabase/migrations/20260723113000_optimize_notification_unread_check.sql',
    );
    expect(repository, contains("'has_unread_notifications'"));
    expect(repository, contains('_unreadCacheTtl'));
    expect(repository, contains('refreshOperational = false'));
    expect(migration, contains('security invoker'));
    expect(migration, contains('limit 1'));
  });
}
