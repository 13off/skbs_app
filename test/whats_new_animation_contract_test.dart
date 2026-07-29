import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('role-aware what is new uses animated navigable slides', () {
    final source = File(
      'lib/features/whats_new/presentation/role_aware_whats_new_gate.dart',
    ).readAsStringSync();

    expect(source, contains('PageView.builder'));
    expect(source, contains('Icons.arrow_back_rounded'));
    expect(source, contains('Icons.arrow_forward_rounded'));
    expect(source, contains('_WhatsNewDemoKind.themeToggle'));
    expect(source, contains('_WhatsNewDemoKind.contribution'));
    expect(source, contains('_WhatsNewDemoKind.recruitment'));
    expect(source, contains('_WhatsNewDemoKind.mobilization'));
    expect(source, contains('_WhatsNewDemoKind.aiActions'));
    expect(source, contains('_WhatsNewDemoKind.documents'));
    expect(source, contains('_WhatsNewDemoKind.developerControls'));
    expect(source, contains('_WhatsNewDemoKind.employeeCabinet'));
    expect(source, contains('disableAnimations'));
    expect(
      source,
      contains('mobile-2026-07-29-full-since-1.1.0+2-v2-role-aware'),
    );
  });
}
