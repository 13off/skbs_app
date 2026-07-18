import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile update summary is shown once for release 1.1.0+2', () {
    final gate = File(
      'lib/features/whats_new/presentation/whats_new_gate.dart',
    ).readAsStringSync();
    final mainScreen = File('lib/screens/main_screen.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('version: 1.1.0+2'));
    expect(gate, contains("releaseId = 'mobile-2026-07-18-1.1.0+2'"));
    expect(gate, contains("'whats_new_seen_release'"));
    expect(gate, contains('SharedPreferences.getInstance()'));
    expect(gate, contains('Изменения после версии от 11.07.2026, 17:30'));
    expect(gate, contains('Кандидаты и документы'));
    expect(gate, contains('Цели и задачи'));
    expect(gate, contains('Уведомления'));
    expect(gate, contains('ИИ-помощник'));
    expect(gate, contains('Компания и доступ'));
    expect(gate, contains("label: const Text('Понятно')"));
    expect(mainScreen, contains('WhatsNewGate(child: buildPlatform())'));
  });
}
