import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical global voice UI remains intentionally disabled', () {
    final layer = File(
      'lib/features/ai/presentation/global_voice_assistant_layer_v2.dart',
    ).readAsStringSync();
    final authOverlay = File(
      'lib/features/ai/presentation/global_voice_assistant_auth_overlay.dart',
    ).readAsStringSync();

    expect(layer, contains('class GlobalVoiceAssistantLayerV2'));
    expect(layer, contains('Widget build(BuildContext context) => child;'));
    expect(layer, isNot(contains('GlobalVoiceAssistantRepository.request(')));
    expect(authOverlay, contains('Widget build(BuildContext context) => child;'));
  });
}
