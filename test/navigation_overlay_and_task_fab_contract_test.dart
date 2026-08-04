import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('all main shells float navigation above page content', () {
    final mainShell = source(
      'lib/features/shell/presentation/premium_main_screen.dart',
    );
    final persistentShell = source(
      'lib/features/shell/presentation/persistent_tab_shell.dart',
    );

    expect(mainShell, contains('body: Stack('));
    expect(mainShell, contains('child: _PremiumBottomBar('));
    expect(mainShell, isNot(contains('bottomNavigationBar: _PremiumBottomBar(')));
    expect(persistentShell, contains('extendBody: true'));
    expect(persistentShell, contains('backgroundColor: Colors.transparent'));
    expect(persistentShell, contains('child: ProfessionalBottomNavigation('));
    expect(
      persistentShell,
      isNot(contains('bottomNavigationBar: ProfessionalBottomNavigation(')),
    );
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
}
