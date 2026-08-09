import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('global voice leaves a dedicated bottom clearance for company chat', () {
    final overlay = File(
      'lib/features/ai/presentation/global_voice_assistant_auth_overlay.dart',
    ).readAsStringSync();

    expect(overlay, contains('const _globalVoiceBottomClearance = 88.0'));
    expect(overlay, contains('Positioned.fill('));
    expect(overlay, contains('bottom: _globalVoiceBottomClearance'));
    expect(overlay, contains('child: const SizedBox.expand()'));
  });
}
