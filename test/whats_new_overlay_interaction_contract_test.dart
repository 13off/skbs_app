import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('whats new blocks first-run overlay until modal is closed', () {
    final coordinator = source(
      'lib/navigation/app_modal_overlay_coordinator.dart',
    );
    final whatsNew = source(
      'lib/features/whats_new/presentation/role_aware_whats_new_gate.dart',
    );
    final guide = source(
      'lib/features/onboarding/presentation/first_run_guide.dart',
    );
    final dialog = source(
      'lib/features/whats_new/presentation/whats_new_dialog.dart',
    );

    expect(coordinator, contains('class AppModalOverlayCoordinator'));
    expect(coordinator, contains('waitUntilUnblocked'));
    expect(whatsNew, contains('AppModalOverlayCoordinator.begin'));
    expect(whatsNew, contains('AppModalOverlayCoordinator.end'));
    expect(whatsNew, contains('Positioned.fill('));
    expect(whatsNew, contains('_WhatsNewDialog('));
    expect(whatsNew, isNot(contains('showDialog<void>(')));
    expect(
      guide,
      contains('AppModalOverlayCoordinator.waitUntilUnblocked()'),
    );
    expect(
      guide,
      contains('AppModalOverlayCoordinator.hasBlockingOverlay'),
    );
    expect(
      dialog,
      contains('SingleActivator(LogicalKeyboardKey.escape)'),
    );
    expect(dialog, contains('widget.onClose()'));
  });
}
