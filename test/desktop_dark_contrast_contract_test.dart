import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop screens use the adaptive palette instead of light constants', () {
    final paths = <String>[
      'lib/screens/adaptive_home_base_screen.dart',
      'lib/screens/desktop_home_widgets.dart',
      'lib/screens/desktop_employees_view.dart',
      'lib/screens/desktop_tasks_screen.dart',
    ];

    for (final path in paths) {
      final source = File(path).readAsStringSync();
      expect(source, contains('AppAdaptivePalette'), reason: path);
      expect(
        source,
        isNot(contains('const Color _text = Color(0xFF1F2328)')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('const Color _muted = Color(0xFF6B7075)')),
        reason: path,
      );
    }
  });

  test('desktop employee filters and table stay dark in dark mode', () {
    final source = File(
      'lib/screens/desktop_employees_view.dart',
    ).readAsStringSync();

    expect(source, contains('fillColor: _input'));
    expect(source, contains('dropdownColor: _surfaceElevated'));
    expect(source, contains('? AppAdaptivePalette.disabledSurface'));
    expect(source, contains('? _surfaceElevated'));
    expect(source, contains(': _surface,'));
    expect(source, contains('_success.withValues(alpha: 0.16)'));
    expect(source, contains('_warning.withValues(alpha: 0.16)'));
    expect(source, contains('_danger.withValues(alpha: 0.16)'));
  });

  test('desktop home and tasks expose readable content states', () {
    final home = File(
      'lib/screens/desktop_home_widgets.dart',
    ).readAsStringSync();
    final tasks = File(
      'lib/screens/desktop_tasks_screen.dart',
    ).readAsStringSync();

    expect(home, contains('Color get _text => AppAdaptivePalette.textPrimary'));
    expect(home, contains('Color get _muted => AppAdaptivePalette.textMuted'));
    expect(home, contains('color: _surfaceElevated'));
    expect(home, contains('color: _input'));

    expect(tasks, contains('Color get _text => AppAdaptivePalette.textPrimary'));
    expect(tasks, contains('Color get _muted => AppAdaptivePalette.textMuted'));
    expect(tasks, contains('fillColor: _input'));
    expect(tasks, contains('dropdownColor: _surfaceElevated'));
    expect(tasks, contains('color: _surface'));
    expect(tasks, contains("title: 'На эту дату задач нет'"));
  });

  test('disabled controls remain visible without becoming active', () {
    final palette = File(
      'lib/app/app_adaptive_palette.dart',
    ).readAsStringSync();
    final tasks = File(
      'lib/screens/desktop_tasks_screen.dart',
    ).readAsStringSync();

    expect(palette, contains('darkDisabledSurface = Color(0xFF22303D)'));
    expect(palette, contains('darkDisabledText = Color(0xFF8DA1B4)'));
    expect(tasks, contains('onPressed: sourceForAct.isEmpty ? null'));
    expect(tasks, contains('onPressed: canCreateTask ? openAddTaskScreen : null'));
  });

  test('contrast patch remains presentation-only', () {
    for (final path in <String>[
      'lib/app/app_adaptive_palette.dart',
      'lib/screens/adaptive_home_base_screen.dart',
      'lib/screens/desktop_home_widgets.dart',
      'lib/screens/desktop_employees_view.dart',
      'lib/screens/desktop_tasks_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')), reason: path);
      expect(source, isNot(contains('Supabase.instance.client')), reason: path);
      expect(source, isNot(contains(".from('")), reason: path);
      expect(source, isNot(contains('.rpc(')), reason: path);
    }
  });
}
