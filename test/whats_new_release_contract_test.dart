import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile update summary is shown once for release 1.2.0+3', () {
    final gate = File(
      'lib/features/whats_new/presentation/whats_new_gate.dart',
    ).readAsStringSync();
    final mainScreen = File('lib/screens/main_screen.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('version: 1.2.0+3'));
    expect(gate, contains("releaseId = 'mobile-2026-07-18-1.2.0+3'"));
    expect(gate, contains("'whats_new_seen_release'"));
    expect(gate, contains('SharedPreferences.getInstance()'));
    expect(gate, contains('Изменения после версии 1.1.0+2'));
    expect(gate, contains('ИИ-оператор и диспетчер'));
    expect(gate, contains('Отдельная профессия «Разработчик»'));
    expect(gate, contains('Системные настройки'));
    expect(gate, contains("label: const Text('Понятно')"));
    expect(mainScreen, contains('WhatsNewGate(child: buildPlatform())'));
  });
}
