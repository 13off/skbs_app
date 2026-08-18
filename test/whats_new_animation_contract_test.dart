import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('August 12+ what is new uses dark animated navigable scenes', () {
    final gate = File(
      'lib/features/whats_new/presentation/role_aware_whats_new_gate.dart',
    ).readAsStringSync();
    final dialog = File(
      'lib/features/whats_new/presentation/whats_new_dialog.dart',
    ).readAsStringSync();
    final managerLegal = File(
      'lib/features/whats_new/presentation/whats_new_preview_manager_legal.dart',
    ).readAsStringSync();
    final visualPhotos = File(
      'lib/features/whats_new/presentation/whats_new_preview_visual_photos.dart',
    ).readAsStringSync();
    final source = '$gate\n$dialog\n$managerLegal\n$visualPhotos';

    expect(source, contains('PageView.builder'));
    expect(source, contains('Icons.arrow_back_rounded'));
    expect(source, contains('Icons.arrow_forward_rounded'));
    expect(source, contains('class _AnimatedUpdatePreview'));
    expect(source, contains('AnimationController'));
    expect(source, contains('disableAnimations'));
    expect(source, contains('BackdropFilter'));
    expect(source, contains('ImageFilter.blur'));
    expect(source, contains('_UpdatePreviewKind.managerTodos'));
    expect(source, contains('_UpdatePreviewKind.fines'));
    expect(source, contains('_UpdatePreviewKind.legal'));
    expect(source, contains('_UpdatePreviewKind.glass'));
    expect(source, contains('_UpdatePreviewKind.photos'));
    expect(source, contains('_UpdatePreviewKind.stability'));
    expect(
      source,
      contains('mobile-2026-08-18-since-2026-08-12-v1'),
    );
  });
}
