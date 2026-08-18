import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('global voice UI no longer loads live domain lists', () {
    final layer = File(
      'lib/features/ai/presentation/global_voice_assistant_layer_v2.dart',
    ).readAsStringSync();

    expect(layer, contains('Widget build(BuildContext context) => child;'));
    expect(layer, isNot(contains('RecruitmentRepository.fetchApplications')));
    expect(layer, isNot(contains('Future.wait')));
  });
}
