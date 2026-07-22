import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile update summary is shown once for release 1.3.0+4', () {
    final gate = File(
      'lib/features/whats_new/presentation/whats_new_gate.dart',
    ).readAsStringSync();
    final mainScreen = File('lib/screens/main_screen.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('version: 1.3.0+4'));
    expect(gate, contains("releaseId = 'mobile-2026-07-22-1.3.0+4'"));
    expect(gate, contains("'whats_new_seen_release'"));
    expect(gate, contains('SharedPreferences.getInstance()'));
    expect(gate, contains('Изменения после версии 1.2.0+3'));
    expect(gate, contains('Полноценная тёмная тема'));
    expect(gate, contains('Удобная работа на компьютере'));
    expect(gate, contains('Ограничения по объектам и ролям'));
    expect(gate, contains('Журнал действий и корзина'));
    expect(gate, contains("label: const Text('Понятно')"));
    expect(mainScreen, contains('WhatsNewGate(child: buildPlatform())'));
  });
}
