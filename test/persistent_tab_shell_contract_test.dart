import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('руководитель и прораб используют общую постоянную навигацию', () {
    final shell = source(
      'lib/features/shell/presentation/persistent_tab_shell.dart',
    );
    final manager = source(
      'lib/features/reports/presentation/manager_main_screen.dart',
    );
    final foreman = source(
      'lib/features/foreman/presentation/foreman_main_screen.dart',
    );

    expect(shell, contains('class PersistentTabController'));
    expect(shell, contains('class PersistentTabShell'));
    expect(shell, contains('PageController'));
    expect(shell, contains('List<GlobalKey<NavigatorState>>'));
    expect(shell, contains('navigator.popUntil((route) => route.isFirst)'));
    expect(shell, contains('pageController.animateToPage'));
    expect(shell, contains('PageView.builder'));
    expect(shell, contains('ProfessionalBottomNavigation'));

    expect(manager, contains('PersistentTabController(pageCount: pageCount)'));
    expect(manager, contains('PersistentTabShell('));
    expect(manager, contains('returnToFirstTabOnBack: true'));
    expect(manager, contains("label: 'Главная'"));
    expect(manager, contains("label: 'Отчёты'"));
    expect(manager, isNot(contains('PageView.builder')));

    expect(foreman, contains('PersistentTabController(pageCount: pageCount)'));
    expect(foreman, contains('PersistentTabShell('));
    expect(foreman, contains('returnToFirstTabOnBack: false'));
    expect(foreman, contains('premium.MainScreen(profile: profile)'));
    expect(foreman, contains("label: 'Смена'"));
    expect(foreman, contains("label: 'Табель'"));
    expect(foreman, isNot(contains('PageView.builder')));
  });
}
