import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('global voice overlay is disabled at both shell layers', () {
    final layer = File(
      'lib/features/ai/presentation/global_voice_assistant_layer_v2.dart',
    ).readAsStringSync();
    final authOverlay = File(
      'lib/features/ai/presentation/global_voice_assistant_auth_overlay.dart',
    ).readAsStringSync();

    expect(layer, contains('Widget build(BuildContext context) => child;'));
    expect(layer, isNot(contains('_buildLauncher')));
    expect(layer, isNot(contains('Positioned(')));
    expect(authOverlay, contains('Widget build(BuildContext context) => child;'));
    expect(authOverlay, isNot(contains('UserRepository.fetchCurrentProfile')));
  });
}
