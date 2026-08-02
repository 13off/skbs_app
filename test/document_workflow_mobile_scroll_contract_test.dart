import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const screens = <String>[
    'lib/features/documents/presentation/document_workflow_screen.dart',
    'lib/features/documents/presentation/document_onboarding_screen.dart',
    'lib/features/documents/presentation/document_package_management_screen.dart',
    'lib/features/documents/presentation/document_generation_screen.dart',
  ];

  test('document AppPage screens do not nest RefreshIndicator ListViews', () {
    for (final path in screens) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('return RefreshIndicator(')), reason: path);
      expect(source, contains('onRefresh:'), reason: path);
    }
  });
}
