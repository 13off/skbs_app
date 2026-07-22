import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('login uses adaptive card fields keyboard and errors', () {
    final screen = source(
      'lib/features/auth/presentation/premium_login_screen_v2.dart',
    );

    expect(screen, contains('AppAdaptivePalette.surfaceElevated'));
    expect(screen, contains('AppAdaptivePalette.inputSurface'));
    expect(screen, contains('AppAdaptivePalette.border'));
    expect(screen, contains('AppAdaptivePalette.textPrimary'));
    expect(screen, contains('AppAdaptivePalette.textMuted'));
    expect(screen, contains('AppAdaptivePalette.danger'));
    expect(screen, contains('AppAdaptivePalette.success'));
    expect(screen, contains('AppAdaptivePalette.isDark'));
    expect(screen, contains('UserRepository.signIn('));
    expect(screen, contains("label: 'Войти в систему'"));
    expect(screen, isNot(contains('fillColor: Colors.white')));
    expect(
      screen,
      isNot(contains('color: Colors.white.withValues(alpha: 0.80)')),
    );
    expect(screen, isNot(contains('keyboardAppearance: Brightness.light')));
    expect(screen, isNot(contains('AppColors.textPrimary')));
    expect(screen, isNot(contains('AppColors.textMuted')));
  });

  test('company signup uses adaptive working surfaces and errors', () {
    final screen = source(
      'lib/features/auth/presentation/company_signup_screen.dart',
    );

    expect(screen, contains('AppAdaptivePalette.surfaceElevated'));
    expect(screen, contains('AppAdaptivePalette.inputSurface'));
    expect(screen, contains('AppAdaptivePalette.surfaceSoft'));
    expect(screen, contains('AppAdaptivePalette.border'));
    expect(screen, contains('AppAdaptivePalette.danger'));
    expect(screen, contains('UserRepository.signUpCompany('));
    expect(screen, contains("label: 'Создать компанию'"));
    expect(screen, isNot(contains('Colors.white.withValues(alpha: 0.84)')));
    expect(screen, isNot(contains('Color(0xFFFFF2F1)')));
    expect(screen, isNot(contains('Color(0xFFF1F2F3)')));
    expect(screen, isNot(contains('AppColors.textPrimary')));
    expect(screen, isNot(contains('AppColors.textMuted')));
  });

  test('auth status message follows the selected theme', () {
    final gate = source(
      'lib/features/auth/presentation/premium_auth_gate_v2.dart',
    );

    expect(gate, contains('AppAdaptivePalette.surfaceElevated'));
    expect(gate, contains('AppAdaptivePalette.accentSoft'));
    expect(gate, contains('AppAdaptivePalette.border'));
    expect(gate, contains('AppAdaptivePalette.textPrimary'));
    expect(gate, contains('AppAdaptivePalette.textMuted'));
    expect(gate, contains('UserRepository.fetchCurrentProfile('));
    expect(gate, isNot(contains('Colors.white.withValues(alpha: 0.82)')));
    expect(gate, isNot(contains('AppColors.textPrimary')));
    expect(gate, isNot(contains('AppColors.textMuted')));
  });

  test('invitation password screen is adaptive and keeps save flow', () {
    final screen = source(
      'lib/features/auth/presentation/set_invitation_password_screen.dart',
    );

    expect(screen, contains('AppAdaptivePalette.surfaceElevated'));
    expect(screen, contains('AppAdaptivePalette.border'));
    expect(screen, contains('AppAdaptivePalette.textPrimary'));
    expect(screen, contains('AppAdaptivePalette.textMuted'));
    expect(screen, contains('AppAdaptivePalette.danger'));
    expect(screen, contains('AppAdaptivePalette.isDark'));
    expect(screen, contains('UserRepository.setInvitationPassword(password)'));
    expect(screen, contains("label: 'Сохранить пароль'"));
    expect(screen, isNot(contains('Colors.white.withValues(alpha: 0.86)')));
    expect(screen, isNot(contains('Color(0xFF874540)')));
    expect(screen, isNot(contains('AppColors.textPrimary')));
  });
}
