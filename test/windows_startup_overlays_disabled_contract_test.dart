import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('Windows skips startup presentation overlays', () {
    final whatsNew = source(
      'lib/features/whats_new/presentation/role_aware_whats_new_gate.dart',
    );
    final guide = source(
      'lib/features/onboarding/presentation/first_run_guide.dart',
    );

    expect(
      whatsNew,
      contains('defaultTargetPlatform == TargetPlatform.windows'),
    );
    expect(whatsNew, contains('if (_skipOnWindowsDesktop) return;'));
    expect(
      guide,
      contains('defaultTargetPlatform == TargetPlatform.windows'),
    );
    expect(guide, contains('return false;'));
  });
}
