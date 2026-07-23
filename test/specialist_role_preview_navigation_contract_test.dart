import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void expectPersistentTabNavigation(String path) {
  final contents = source(path);
  final shell = source(
    'lib/features/shell/presentation/persistent_tab_shell.dart',
  );

  expect(contents, contains('PersistentTabController tabs'));
  expect(contents, contains('PersistentTabShell('));
  expect(contents, contains('tabBuilder: (context, index) => rootPage(index)'));
  expect(contents, isNot(contains('PageView.builder')));

  expect(shell, contains('List<GlobalKey<NavigatorState>> navigatorKeys'));
  expect(shell, contains('return RepaintBoundary('));
  expect(shell, contains('child: Navigator('));
  expect(shell, contains('onGenerateRoute: (settings)'));
  expect(shell, contains('widget.tabBuilder(context, index)'));
  expect(shell, contains('navigator.popUntil((route) => route.isFirst)'));
  expect(shell, contains('return WillPopScope('));
}

void main() {
  test('платформа юриста открывает вложенные экраны внутри своей вкладки', () {
    expectPersistentTabNavigation(
      'lib/features/legal/presentation/legal_main_screen.dart',
    );
  });

  test('платформа бухгалтера открывает вложенные экраны внутри своей вкладки', () {
    expectPersistentTabNavigation(
      'lib/features/accounting/presentation/accounting_main_screen.dart',
    );
  });
}
