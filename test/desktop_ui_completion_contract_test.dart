import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop directory receives a clean position without losing phone data', () {
    final employee = File('lib/models/employee.dart').readAsStringSync();
    final adaptiveDirectory = File(
      'lib/screens/adaptive_employees_screen.dart',
    ).readAsStringSync();

    expect(employee, contains('String get positionTitle'));
    expect(employee, contains('String get positionWithContact'));
    expect(employee, contains('phone: phone.trim(),'));
    expect(adaptiveDirectory, contains('employee.positionTitle'));
    expect(adaptiveDirectory, contains('phone: employee.phone'));
    expect(
      adaptiveDirectory,
      contains('.map(prepareForDesktopDirectory)'),
    );
  });

  test('shared AppPage expands on desktop and restores nested back navigation', () {
    final source = File('lib/widgets/app_page.dart').readAsStringSync();
    final tokens = File('lib/app/app_ui_tokens.dart').readAsStringSync();

    expect(
      source,
      contains('static const double desktopBreakpoint = AppUi.desktopBreakpoint;'),
    );
    expect(source, contains('this.maxContentWidth = AppUi.pageContentWidth'));
    expect(source, contains('BoxConstraints(maxWidth: maxContentWidth)'));
    expect(tokens, contains('static const double desktopBreakpoint = 1050;'));
    expect(tokens, contains('static const double pageContentWidth = 1180;'));
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
