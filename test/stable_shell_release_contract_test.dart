import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Аварийный контракт: рабочая оболочка экранов должна публиковаться без UI-регрессий.
void main() {
  test('published shell uses the last known-good visible structure', () {
    final source = File(
      'lib/features/shell/presentation/premium_main_screen.dart',
    ).readAsStringSync();

    expect(source, contains("import '../../../navigation/app_page_route.dart';"));
    expect(source, contains('PageView.builder'));
    expect(source, contains('AppPageRoute<void>('));
    expect(
      source,
      contains('return buildRootPage(index, selectedObjectName);'),
    );
    expect(source, isNot(contains('final isDesktop = screenWidth >= 760')));
  });

  test('release workflow safely replaces the public snapshot', () {
    final workflow = File(
      '.github/workflows/deploy-web.yml',
    ).readAsStringSync();

    expect(workflow, contains('Publish one clean root snapshot'));
    expect(workflow, contains('git checkout --orphan deploy-snapshot'));
    expect(workflow, contains('git push --force-with-lease='));
    expect(workflow, contains('cancel-in-progress: true'));
    expect(workflow, contains(r'test "$count" = "1"'));
    expect(workflow, contains(r'test "$parents" = "0"'));
  });
}
