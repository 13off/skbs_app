import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('private data stores compact payout requisites', () {
    final model = File(
      'lib/models/employee_private_data.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/screens/employee_private_data_screen.dart',
    ).readAsStringSync();

    expect(model, contains('bankTransferPhone'));
    expect(model, contains('bankRecipientName'));
    expect(model, contains("'bank_transfer_phone'"));
    expect(model, contains("'bank_recipient_name'"));

    expect(screen, contains('Телефон для перевода'));
    expect(screen, contains('Получатель / владелец карты'));
    expect(screen, contains('bankTransferPhoneController'));
    expect(screen, contains('bankRecipientNameController'));
  });

  test('executive reads payout requisites through narrow RPC only', () {
    final repository = File(
      'lib/features/executive/data/executive_panel_repository.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260919171000_add_executive_payment_requisites.sql',
    ).readAsStringSync();

    expect(
      repository,
      contains("'get_executive_payment_requisites'"),
    );
    expect(
      repository,
      isNot(contains("from('employee_private_data')")),
    );

    expect(migration, contains('bank_transfer_phone text'));
    expect(migration, contains('bank_name text'));
    expect(migration, contains('bank_recipient_name text'));
    expect(migration, contains('bank_card text'));

    expect(migration, isNot(contains('passport_series')));
    expect(migration, isNot(contains('passport_number')));
    expect(migration, isNot(contains('snils')));
    expect(migration, isNot(contains('registration_address')));
    expect(migration, isNot(contains('create policy')));
  });

  test('executive payment rows copy requisites without displaying them', () {
    final screen = File(
      'lib/features/executive/presentation/executive_main_screen.dart',
    ).readAsStringSync();

    expect(screen, contains('Скопировать реквизиты'));
    expect(screen, contains('Реквизиты скопированы'));
    expect(screen, contains('_copyPaymentRequisites'));
    expect(screen, isNot(contains('Паспорт:')));
    expect(screen, isNot(contains('СНИЛС:')));
  });

  test('express summary supports copy txt and xlsx', () {
    final screen = File(
      'lib/features/executive/presentation/executive_main_screen.dart',
    ).readAsStringSync();
    final exporter = File(
      'lib/features/executive/data/executive_payment_summary_exporter.dart',
    ).readAsStringSync();

    expect(screen, contains('Экспресс-сводка'));
    expect(screen, contains('Скопировать текст'));
    expect(screen, contains('Скачать TXT'));
    expect(screen, contains('Скачать XLSX'));

    expect(exporter, contains('FileSaver.instance.saveFile'));
    expect(exporter, contains("fileExtension: 'txt'"));
    expect(exporter, contains("fileExtension: 'xlsx'"));
    expect(exporter, contains('Телефон для перевода'));
    expect(exporter, contains('Получатель'));
    expect(exporter, contains('Карта'));
    expect(exporter, contains('Остаток системы'));
    expect(exporter, contains('К выплате'));

    expect(exporter, isNot(contains('Паспорт')));
    expect(exporter, isNot(contains('СНИЛС')));
    expect(exporter, isNot(contains('ИНН')));
  });

  test('private data changes refresh executive payment data', () {
    final repository = File(
      'lib/data/employee_private_data_repository.dart',
    ).readAsStringSync();
    final sync = File('lib/data/app_data_sync.dart').readAsStringSync();

    expect(repository, contains('AppDataSync.notifyLocal'));
    expect(repository, contains('AppDataDomain.employees'));
    expect(sync, contains("case 'employee_private_data':"));
    expect(sync, contains('AppDataDomain.employees'));
  });
}
