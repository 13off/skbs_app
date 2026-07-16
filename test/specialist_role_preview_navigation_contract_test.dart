import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void expectLocalTabNavigation(String path) {
  final contents = source(path);

  expect(contents, contains("import 'package:flutter/cupertino.dart' show CupertinoPageRoute;"));
  expect(contents, contains('List<GlobalKey<NavigatorState>> navigatorKeys'));
  expect(contents, contains('Widget buildTabNavigator(int index)'));
  expect(contents, contains('return Navigator('));
  expect(contents, contains('onGenerateRoute: (settings)'));
  expect(contents, contains('builder: (_) => rootPage(index)'));
  expect(contents, contains('navigator.popUntil((route) => route.isFirst)'));
  expect(contents, contains('return WillPopScope('));
  expect(contents, contains('itemBuilder: (context, index) => buildTabNavigator(index)'));
}

void main() {
  test('платформа юриста открывает вложенные экраны внутри своей вкладки', () {
    expectLocalTabNavigation(
      'lib/features/legal/presentation/legal_main_screen.dart',
    );
  });

  test('платформа бухгалтера открывает вложенные экраны внутри своей вкладки', () {
    expectLocalTabNavigation(
      'lib/features/accounting/presentation/accounting_main_screen.dart',
    );
  });
}
