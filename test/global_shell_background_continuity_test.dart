import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/widgets/app_page.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('all tab shells share one continuous AppSurfaceBackdrop', () {
    final persistent = source(
      'lib/features/shell/presentation/persistent_tab_shell.dart',
    );
    final legacy = source(
      'lib/features/shell/presentation/premium_main_screen.dart',
    );
    final backdrop = source('lib/widgets/app_page.dart');

    for (final shell in <String>[persistent, legacy]) {
      expect(shell, contains('child: AppSurfaceBackdrop('));
      expect(shell, contains('backgroundColor: Colors.transparent'));
      expect(shell, contains('bottomNavigationBar:'));
      expect(shell, isNot(contains('extendBody: true')));
    }

    expect(backdrop, contains('class _AppSurfaceBackdropScope'));
    expect(backdrop, contains("ValueKey('app-surface-backdrop-layer')"));
    expect(
      backdrop,
      contains('if (_AppSurfaceBackdropScope.maybeOf(context)) return child;'),
    );
  });

  testWidgets('nested page backdrops reuse the same painted layer', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppSurfaceBackdrop(
          child: AppSurfaceBackdrop(child: SizedBox.expand()),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('app-surface-backdrop-layer')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
