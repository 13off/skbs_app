import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  // Эти проверки защищают именно рабочие поверхности, а не декоративный
  // белый текст на акцентных кнопках.
  test('archive uses adaptive surfaces and text colors', () {
    final archive = source(
      'lib/features/archive/presentation/archive_management_screen.dart',
    );

    expect(
      archive,
      contains("import '../../../app/app_adaptive_palette.dart';"),
    );
    expect(archive, contains('AppAdaptivePalette.surface'));
    expect(archive, contains('AppAdaptivePalette.surfaceSoft'));
    expect(archive, contains('AppAdaptivePalette.border'));
    expect(archive, contains('AppAdaptivePalette.textPrimary'));
    expect(archive, contains('AppAdaptivePalette.textMuted'));
    expect(archive, contains('AppAdaptivePalette.onAccent'));
    expect(archive, isNot(contains('color: Colors.white,')));
    expect(archive, isNot(contains('AppColors.textPrimary')));
    expect(archive, isNot(contains('AppColors.textMuted')));
    expect(archive, isNot(contains('AppColors.surfaceSoft')));
    expect(archive, isNot(contains('AppColors.border')));
  });

  test('payments use adaptive cards search and semantic states', () {
    final payments = source(
      'lib/features/payments/presentation/screens/payments_screen.dart',
    );

    expect(
      payments,
      contains("import '../../../../app/app_adaptive_palette.dart';"),
    );
    expect(payments, contains('AppAdaptivePalette.inputSurface'));
    expect(payments, contains('AppAdaptivePalette.surfaceElevated'));
    expect(payments, contains('AppAdaptivePalette.border'));
    expect(payments, contains('AppAdaptivePalette.textPrimary'));
    expect(payments, contains('AppAdaptivePalette.textMuted'));
    expect(payments, contains('AppAdaptivePalette.success'));
    expect(payments, contains('AppAdaptivePalette.danger'));
    expect(payments, isNot(contains('fillColor: Colors.white')));
    expect(payments, isNot(contains('color: Colors.white,')));
    expect(payments, isNot(contains('AppColors.textPrimary')));
    expect(payments, isNot(contains('AppColors.textMuted')));
  });
}
