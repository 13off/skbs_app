import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile update summary is shown once for release 1.3.1+5', () {
    final gate = File(
      'lib/features/whats_new/presentation/whats_new_gate.dart',
    ).readAsStringSync();
    final guide = File(
      'lib/features/onboarding/presentation/first_run_guide.dart',
    ).readAsStringSync();
    final mainScreen = File('lib/screens/main_screen.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('version: 1.3.1+5'));
    expect(
      gate,
      contains("releaseId = 'mobile-2026-07-29-animated-whats-new'"),
    );
    expect(gate, contains("'whats_new_seen_release'"));
    expect(gate, contains('SharedPreferences.getInstance()'));
    expect(gate, contains('FirstRunGuide.showIfNeeded'));
    expect(gate, contains('Единый кабинет сотрудника'));
    expect(gate, contains('Отчёты разделены по страницам'));
    expect(gate, contains('Тема меняется плавно'));
    expect(gate, contains('Рабочие показатели стали нагляднее'));
    expect(gate, contains('PageView.builder'));
    expect(gate, contains("Text(_isLast ? 'Готово' : 'Далее')"));
    expect(guide, contains("version = '2026-07-28-v5-overlay-space'"));
    expect(guide, contains('WidgetsBinding.instance.rootElement'));
    expect(guide, contains('globalToLocal'));
    expect(guide, contains('OverlayEntry('));
    expect(guide, contains("'Обучение · \${profile.roleTitle}'"));
    expect(
      mainScreen,
      contains('WhatsNewGate(profile: widget.profile, child: buildPlatform())'),
    );
  });
}
