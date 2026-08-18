import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('global floating voice control has no position because it is disabled', () {
    final authOverlay = File(
      'lib/features/ai/presentation/global_voice_assistant_auth_overlay.dart',
    ).readAsStringSync();
    final layer = File(
      'lib/features/ai/presentation/global_voice_assistant_layer_v2.dart',
    ).readAsStringSync();

    expect(authOverlay, contains('Widget build(BuildContext context) => child;'));
    expect(layer, contains('Widget build(BuildContext context) => child;'));
    expect(layer, isNot(contains('Positioned(')));
  });
}
