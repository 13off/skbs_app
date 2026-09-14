import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('расходы открывают единые настройки статей и контрагентов', () {
    final expenses = source(
      'lib/features/expenses/presentation/expenses_screen.dart',
    );
    final settings = source(
      'lib/features/expenses/presentation/expense_settings_screen.dart',
    );
    final repository = source(
      'lib/features/expenses/data/expense_repository.dart',
    );

    expect(expenses, contains("tooltip: 'Настройки расходов'"));
    expect(expenses, contains('ExpenseSettingsScreen'));
    expect(settings, contains("value: 'categories'"));
    expect(settings, contains("value: 'counterparties'"));
    expect(settings, contains('repository.createCategory'));
    expect(settings, contains('repository.updateCategory'));
    expect(settings, contains('repository.deleteCategory'));
    expect(settings, contains('repository.createCounterparty'));
    expect(settings, contains('repository.updateCounterparty'));
    expect(settings, contains('repository.deleteCounterparty'));
    expect(repository, contains("from('accounting_counterparties')"));
  });

  test('форма расхода предлагает контрагентов и сохраняет ручной ввод', () {
    final expenses = source(
      'lib/features/expenses/presentation/expenses_screen.dart',
    );

    expect(expenses, contains('RawAutocomplete<ExpenseCounterpartyData>'));
    expect(expenses, contains('textEditingController: counterpartyController'));
    expect(expenses, contains('counterpartyName: counterpartyController.text'));
  });

  test('миграция защищает справочники компанией и ролью', () {
    final migration = source(
      'supabase/migrations/20260912183233_expense_settings_and_counterparty_types.sql',
    );

    expect(migration, contains("check (entity_type in ('legal_entity', 'individual'))"));
    expect(migration, contains('to authenticated'));
    expect(migration, contains('company_id = public.current_user_company_id()'));
    expect(
      migration,
      contains("public.current_user_role() in ('admin', 'developer', 'accountant')"),
    );
  });
}
