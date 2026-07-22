import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('company switcher has no static white working surfaces', () {
    final screen = source(
      'lib/features/company/presentation/company_switcher_screen.dart',
    );

    expect(screen, contains('AppAdaptivePalette.surfaceElevated'));
    expect(screen, contains('AppAdaptivePalette.selectedSurface'));
    expect(screen, contains('AppAdaptivePalette.surfaceSoft'));
    expect(screen, contains('AppAdaptivePalette.border'));
    expect(screen, contains('AppAdaptivePalette.danger'));
    expect(screen, isNot(contains('Colors.white.withValues')));
    expect(screen, isNot(contains('AppColors.textPrimary')));
    expect(screen, isNot(contains('AppColors.textMuted')));
  });

  test('company onboarding uses adaptive card pill and error colors', () {
    final screen = source(
      'lib/features/company/presentation/company_onboarding_screen.dart',
    );

    expect(screen, contains('AppAdaptivePalette.surfaceElevated'));
    expect(screen, contains('AppAdaptivePalette.surfaceSoft'));
    expect(screen, contains('AppAdaptivePalette.border'));
    expect(screen, contains('AppAdaptivePalette.textPrimary'));
    expect(screen, contains('AppAdaptivePalette.textMuted'));
    expect(screen, contains('AppAdaptivePalette.danger'));
    expect(screen, isNot(contains('Colors.white.withValues')));
    expect(screen, isNot(contains('Color(0xFFFFF2F1)')));
    expect(screen, isNot(contains('AppColors.textPrimary')));
  });

  test('mobile company management uses adaptive working surfaces', () {
    final screen = source(
      'lib/features/company/presentation/mobile_company_management_screen.dart',
    );

    expect(screen, contains('AppAdaptivePalette.surfaceElevated'));
    expect(screen, contains('AppAdaptivePalette.surfaceSoft'));
    expect(screen, contains('AppAdaptivePalette.border'));
    expect(screen, contains('AppAdaptivePalette.textPrimary'));
    expect(screen, contains('AppAdaptivePalette.textMuted'));
    expect(screen, contains('AppAdaptivePalette.danger'));
    expect(screen, contains('AppAdaptivePalette.onAccent'));
    expect(screen, isNot(contains('Colors.white.withValues(alpha: 0.86)')));
    expect(screen, isNot(contains('Colors.white.withValues(alpha: 0.84)')));
    expect(screen, isNot(contains('Color(0xFFF0F1F3)')));
    expect(screen, isNot(contains('Color(0xFFF3F4F5)')));
    expect(screen, isNot(contains('AppColors.textPrimary')));
    expect(screen, isNot(contains('AppColors.textMuted')));
  });

  test('desktop company member avatar follows specialist palette', () {
    final dialogs = source(
      'lib/features/company/presentation/desktop_company_user_dialogs.dart',
    );

    expect(dialogs, contains('backgroundColor: specialistSoft'));
    expect(dialogs, contains('foregroundColor: specialistText'));
    expect(
      dialogs,
      isNot(contains('backgroundColor: Colors.white,\n                        child: Icon(Icons.person_outline)')),
    );
  });
}
