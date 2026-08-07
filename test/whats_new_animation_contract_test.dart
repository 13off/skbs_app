import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('major what is new uses dark animated navigable scenes', () {
    final source = File(
      'lib/features/whats_new/presentation/role_aware_whats_new_gate.dart',
    ).readAsStringSync();

    expect(source, contains('PageView.builder'));
    expect(source, contains('Icons.arrow_back_rounded'));
    expect(source, contains('Icons.arrow_forward_rounded'));
    expect(source, contains('class _AnimatedUpdatePreview'));
    expect(source, contains('AnimationController'));
    expect(source, contains('disableAnimations'));
    expect(source, contains('BackdropFilter'));
    expect(source, contains('ImageFilter.blur'));
    expect(source, contains('_UpdatePreviewKind.employee'));
    expect(source, contains('_UpdatePreviewKind.route'));
    expect(source, contains('_UpdatePreviewKind.procurement'));
    expect(source, contains('_UpdatePreviewKind.employment'));
    expect(source, contains('_UpdatePreviewKind.documents'));
    expect(source, contains('_UpdatePreviewKind.flights'));
    expect(source, contains('_UpdatePreviewKind.brand'));
    expect(source, contains('_UpdatePreviewKind.performance'));
    expect(source, contains('_UpdatePreviewKind.bugs'));
    expect(
      source,
      contains('mobile-2026-08-07-role-aware-major-update-v1'),
    );
  });
}
