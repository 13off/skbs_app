import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The legacy manual-code MAX button must stay removed from employee login.
// The secure one-tap implementation is retained for a later re-enable, while
// the public employee entry is intentionally disabled.
void main() {
  test('employee MAX one-tap implementation remains behind disabled entry', () {
    final entry = File(
      'lib/features/auth/presentation/auth_entry_screen.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/auth/presentation/employee_max_login_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/auth/data/employee_auth_repository.dart',
    ).readAsStringSync();
    final loginFunction = File(
      'supabase/functions/employee-max-login/index.ts',
    ).readAsStringSync();
    final maxHook = File(
      'supabase/functions/send-auth-max/index.ts',
    ).readAsStringSync();
    final bridge = File(
      'supabase/functions/max-employee-link-bridge/index.ts',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260729121000_employee_max_one_tap_login.sql',
    ).readAsStringSync();

    expect(entry, contains("import 'employee_max_login_screen.dart';"));
    expect(entry, contains('EmployeeMaxLoginScreen('));
    expect(entry, contains("title: 'Я сотрудник'"));
    expect(entry, contains("subtitle: 'Временно недоступно'"));
    expect(entry, contains('enabled: false'));
    expect(entry, contains('onTap: enabled ? onTap : null'));

    expect(
      screen,
      contains("label: isWaiting ? 'Открыть MAX' : 'Войти через MAX'"),
    );
    expect(screen, contains('EmployeeAuthRepository.requestMaxLogin('));
    expect(screen, contains('EmployeeAuthRepository.pollMaxLogin('));
    expect(screen, contains('Timer.periodic('));
    expect(screen, contains('LaunchMode.externalApplication'));
    expect(screen, contains('AppLifecycleState.resumed'));
    expect(screen, isNot(contains("child: const Text('Войти по коду из MAX')")));

    expect(repository, contains("'employee-max-login'"));
    expect(repository, contains("'action': 'request'"));
    expect(repository, contains("'action': 'poll'"));
    expect(repository, contains('_client.auth.setSession('));
    expect(repository, contains('accessToken: accessToken'));

    expect(loginFunction, contains('client_token_hash'));
    expect(loginFunction, contains('AES-GCM'));
    expect(loginFunction, contains('session_ciphertext'));
    expect(loginFunction, contains('auth.verifyOtp({'));
    expect(loginFunction, contains('type: "sms"'));
    expect(loginFunction, contains('confirm_token_hash'));
    expect(loginFunction, contains('Referrer-Policy'));
    expect(loginFunction, isNot(contains('searchParams.set("otp"')));

    expect(maxHook, contains('text: "Подтвердить вход"'));
    expect(maxHook, contains('employee_max_login_attempts'));
    expect(maxHook, contains('otp_ciphertext'));
    expect(maxHook, contains('confirmToken'));

    expect(bridge, contains('login_attempt_id'));
    expect(bridge, contains('login_started'));
    expect(bridge, contains('auth.signInWithOtp({'));

    expect(migration, contains('employee_max_login_attempts'));
    expect(migration, contains('enable row level security'));
    expect(migration, contains('revoke all'));
    expect(migration, contains('login_attempt_id uuid'));
  });
}
