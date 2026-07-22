import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('employee position stays separate from phone', () {
    final source = File('lib/models/employee.dart').readAsStringSync();

    expect(source, contains('position.trim(),'));
    expect(source, contains('phone: phone.trim(),'));
    expect(source, isNot(contains('positionWithContact')));
    expect(source, isNot(contains("join(' • ')")));
  });

  test('shared AppPage expands on desktop and restores nested back navigation', () {
    final source = File('lib/widgets/app_page.dart').readAsStringSync();

    expect(source, contains('static const double desktopBreakpoint = 1050;'));
    expect(source, contains('final maxContentWidth = isDesktop ? 1180.0 : 720.0;'));
    expect(source, contains('Navigator.maybeOf(context)'));
    expect(source, contains('navigator?.canPop() ?? false'));
    expect(source, contains('showBackButton: effectiveShowBackButton'));
  });

  test('root loading and role preview follow the active theme', () {
    final source = File('lib/screens/main_screen.dart').readAsStringSync();

    expect(source, contains("import '../app/app_adaptive_palette.dart';"));
    expect(source, contains('color: AppAdaptivePalette.background'));
    expect(source, contains('color: AppAdaptivePalette.surfaceElevated'));
    expect(source, contains('color: AppAdaptivePalette.textPrimary'));
    expect(source, isNot(contains('Color(0xFFF8F7F3)')));
  });
}
