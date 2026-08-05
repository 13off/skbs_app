import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('August what is new uses animated navigable slides', () {
    final source = File(
      'lib/features/whats_new/presentation/role_aware_whats_new_gate.dart',
    ).readAsStringSync();

    expect(source, contains('PageView.builder'));
    expect(source, contains('Icons.arrow_back_rounded'));
    expect(source, contains('Icons.arrow_forward_rounded'));
    expect(source, contains('class _AnimatedUpdatePreview'));
    expect(source, contains('AnimationController'));
    expect(source, contains('disableAnimations'));
    expect(source, contains('_UpdatePreviewKind.employee'));
    expect(source, contains('_UpdatePreviewKind.route'));
    expect(source, contains('_UpdatePreviewKind.maxLogin'));
    expect(source, contains('_UpdatePreviewKind.procurement'));
    expect(source, contains('_UpdatePreviewKind.pwa'));
    expect(
      source,
      contains('mobile-2026-08-05-employee-workspace-and-procurement-v1'),
    );
  });
}
