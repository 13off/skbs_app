import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('management startup never renders a silent blank loading state', () {
    final gate = File(
      'lib/features/auth/presentation/resilient_management_auth_gate.dart',
    ).readAsStringSync();
    final router = File(
      'lib/features/auth/presentation/employee_aware_auth_gate.dart',
    ).readAsStringSync();

    expect(router, contains("'resilient_management_auth_gate.dart'"));
    expect(gate, contains('class _StartupLoadingScreen'));
    expect(gate, contains("'Загружаем профиль и компанию…'"));
    expect(gate, contains('Duration(seconds: 12)'));
    expect(gate, contains('on TimeoutException'));
    expect(gate, contains("secondActionText: 'Выйти из аккаунта'"));
    expect(gate, isNot(contains('screen = const SizedBox.expand()')));
  });

  test('duplicate auth events do not restart the same profile request', () {
    final gate = File(
      'lib/features/auth/presentation/resilient_management_auth_gate.dart',
    ).readAsStringSync();

    expect(gate, contains('bool loadInFlight = false'));
    expect(gate, contains('currentUserId == loadingUserId'));
    expect(gate, contains('loadInFlight = true'));
    expect(gate, contains('loadInFlight = false'));
  });
}
