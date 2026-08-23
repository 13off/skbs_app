import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('employee MAX entry stays visible but disabled', () {
    final entry = File(
      'lib/features/auth/presentation/auth_entry_screen.dart',
    ).readAsStringSync();

    final employeeChoiceStart = entry.indexOf("title: 'Я сотрудник'");
    final specialistChoiceStart = entry.indexOf(
      "title: 'Руководитель или специалист'",
    );

    expect(employeeChoiceStart, greaterThanOrEqualTo(0));
    expect(specialistChoiceStart, greaterThan(employeeChoiceStart));

    final employeeChoice = entry.substring(
      employeeChoiceStart,
      specialistChoiceStart,
    );
    expect(employeeChoice, contains("subtitle: 'Временно недоступно'"));
    expect(employeeChoice, contains('enabled: false'));

    expect(entry, contains('onTap: enabled ? onTap : null'));
    expect(entry, contains('Icons.lock_outline_rounded'));
  });

  test('specialist login remains enabled', () {
    final entry = File(
      'lib/features/auth/presentation/auth_entry_screen.dart',
    ).readAsStringSync();

    final specialistChoiceStart = entry.indexOf(
      "title: 'Руководитель или специалист'",
    );
    expect(specialistChoiceStart, greaterThanOrEqualTo(0));

    final specialistChoice = entry.substring(specialistChoiceStart);
    expect(specialistChoice, contains('openManagementLogin(context)'));
    expect(specialistChoice, isNot(contains('enabled: false')));
  });

  test('MAX recruiting bot cannot be redeployed while disabled', () {
    final workflow = File(
      '.github/workflows/deploy-max-bot-vps.yml',
    ).readAsStringSync();

    expect(workflow, contains('MAX recruiting bot temporarily disabled'));
    expect(workflow, contains('Keep MAX bot disabled'));
    expect(workflow, isNot(contains('appleboy/scp-action')));
    expect(workflow, isNot(contains('appleboy/ssh-action')));
    expect(workflow, isNot(contains('VPS_HOST')));
    expect(workflow, isNot(contains('docker compose')));
  });
}
