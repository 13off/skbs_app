import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('September release uses role-specific animated scenes', () {
    final gate = File(
      'lib/features/whats_new/presentation/role_aware_whats_new_gate.dart',
    ).readAsStringSync();
    final dialog = File(
      'lib/features/whats_new/presentation/whats_new_dialog.dart',
    ).readAsStringSync();
    final preview = File(
      'lib/features/whats_new/presentation/whats_new_preview_current_release.dart',
    ).readAsStringSync();
    final source = '$gate\n$dialog\n$preview';

    expect(source, contains('PageView.builder'));
    expect(source, contains('Icons.arrow_back_rounded'));
    expect(source, contains('Icons.arrow_forward_rounded'));
    expect(source, contains('class _AnimatedUpdatePreview'));
    expect(source, contains('AnimationController'));
    expect(source, contains('disableAnimations'));
    expect(source, contains('BackdropFilter'));
    expect(source, contains('ImageFilter.blur'));
    expect(source, contains('_UpdatePreviewKind.taskMedia'));
    expect(source, contains('_UpdatePreviewKind.decimalMoney'));
    expect(source, contains('_UpdatePreviewKind.advanceThirty'));
    expect(source, contains('class _TaskMediaScene'));
    expect(source, contains('class _DecimalMoneyScene'));
    expect(source, contains('class _AdvanceThirtyScene'));
    expect(source, contains('mobile-2026-09-26-1.3.10+24-v1'));
  });
}
