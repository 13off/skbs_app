import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persistent tabs are lazy and do not prewarm hidden workspaces', () {
    final shell = File(
      'lib/features/shell/presentation/persistent_tab_shell.dart',
    ).readAsStringSync();

    expect(shell, contains('_ensureTabBuilt(widget.controller.currentIndex);'));
    expect(shell, contains('setState(() => _ensureTabBuilt(index));'));
    expect(shell, contains('final Map<int, Widget> _tabNavigators'));
    expect(shell, contains('body: IndexedStack('));
    expect(shell, contains('TickerMode(enabled: index == activeIndex'));

    expect(shell, isNot(contains('scheduleTask')));
    expect(shell, isNot(contains('Priority.idle')));
    expect(shell, isNot(contains('_scheduleTabPrewarm')));
    expect(shell, isNot(contains('_prewarmNextTab')));
    expect(shell, isNot(contains('AppStroy.prewarmTab')));
    expect(shell, isNot(contains("package:flutter/scheduler.dart")));
  });

  test('visited tabs stay mounted so navigation state is preserved', () {
    final shell = File(
      'lib/features/shell/presentation/persistent_tab_shell.dart',
    ).readAsStringSync();

    expect(shell, contains('_tabNavigators.putIfAbsent'));
    expect(shell, isNot(contains('_tabNavigators.remove')));
    expect(shell, contains('Navigator('));
    expect(shell, contains('key: widget.controller.navigatorKeys[index]'));
    expect(shell, contains('if (child == null) return const SizedBox.shrink();'));
  });
}
