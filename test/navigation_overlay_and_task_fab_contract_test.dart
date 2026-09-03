import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('all main shells reserve a real navigation area', () {
    final mainShell = source(
      'lib/features/shell/presentation/premium_main_screen.dart',
    );
    final persistentShell = source(
      'lib/features/shell/presentation/persistent_tab_shell.dart',
    );

    expect(mainShell, contains('bottomNavigationBar: _PremiumBottomBar('));
    expect(mainShell, isNot(contains('extendBody: true')));
    expect(mainShell, isNot(contains('legacy-tab-content-clearance')));

    expect(persistentShell, contains('bottomNavigationBar: useDesktopShell'));
    expect(persistentShell, contains('ProfessionalBottomNavigation('));
    expect(persistentShell, contains('_DesktopTabRail('));
    expect(persistentShell, isNot(contains('extendBody: true')));
    expect(
      persistentShell,
      isNot(contains('persistent-tab-content-clearance')),
    );
    expect(mainShell, contains('child: AppSurfaceBackdrop('));
    expect(mainShell, contains('backgroundColor: Colors.transparent'));
    expect(persistentShell, contains('child: AppSurfaceBackdrop('));
    expect(persistentShell, contains('backgroundColor: Colors.transparent'));
  });

  test('dark navigation glass stays graphite instead of black', () {
    final navigation = source(
      'lib/widgets/professional_bottom_navigation.dart',
    );

    expect(navigation, contains('Color(0x8047525D)'));
    expect(navigation, contains('Color(0xCC5B646E)'));
    expect(navigation, contains('Color(0xB34A5662)'));
    expect(navigation, contains('Color(0x99404B56)'));
    expect(navigation, isNot(contains('Color(0x66232C35)')));
  });

  test('mobile add task action is fixed above navigation', () {
    final tasks = source('lib/screens/mobile_tasks_screen.dart');

    expect(tasks, contains("ValueKey('tasks-floating-add')"));
    expect(tasks, contains('bottom: floatingBottom'));
    expect(tasks, contains('AppUi.floatingActionBottom(context)'));
    expect(tasks, contains("label: 'Добавить задачу'"));
    expect(tasks, contains('const SizedBox(height: 78)'));
  });

  test('navigation and task action remain presentation-only changes', () {
    final files = <String>[
      'lib/features/shell/presentation/premium_main_screen.dart',
      'lib/features/shell/presentation/persistent_tab_shell.dart',
      'lib/screens/mobile_tasks_screen.dart',
      'lib/widgets/professional_bottom_navigation.dart',
    ];

    for (final path in files) {
      final value = source(path);
      expect(value, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')), reason: path);
    }
  });
}
