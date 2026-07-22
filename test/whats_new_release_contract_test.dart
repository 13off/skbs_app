import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile update summary is shown once for release 1.3.1+5', () {
    final gate = File(
      'lib/features/whats_new/presentation/whats_new_gate.dart',
    ).readAsStringSync();
    final mainScreen = File('lib/screens/main_screen.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('version: 1.3.1+5'));
    expect(gate, contains("releaseId = 'mobile-2026-07-22-1.3.1+5'"));
    expect(gate, contains("'whats_new_seen_release'"));
    expect(gate, contains('SharedPreferences.getInstance()'));
    expect(gate, contains('Изменения после версии 1.3.0+4'));
    expect(gate, contains('Читаемый ИИ-чат в тёмной теме'));
    expect(gate, contains('Быстрая отправка с клавиатуры'));
    expect(gate, contains('Остальные экраны ИИ'));
    expect(gate, contains('Enter отправляет сообщение в ИИ-чат'));
    expect(gate, contains('Shift+Enter добавляет новую строку'));
    expect(gate, contains("label: const Text('Понятно')"));
    expect(mainScreen, contains('WhatsNewGate(child: buildPlatform())'));
  });
}
