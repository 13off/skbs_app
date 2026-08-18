import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disabled global voice layer does not load live dictionaries', () {
    final layer = File(
      'lib/features/ai/presentation/global_voice_assistant_layer_v2.dart',
    ).readAsStringSync();

    expect(layer, contains('Widget build(BuildContext context) => child;'));
    expect(layer, isNot(contains('_loadVoiceHints')));
    expect(layer, isNot(contains('AppVoiceDictionary')));
  });
}
