import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void containsAll(String path, Iterable<String> fragments) {
  final contents = source(path);
  for (final fragment in fragments) {
    expect(
      contents,
      contains(fragment),
      reason: 'Обязательный элемент "$fragment" отсутствует в $path',
    );
  }
}

void main() {
  test('панель бухгалтера переиспользует рабочие разделы руководителя', () {
    containsAll(
      'lib/features/accounting/presentation/accounting_main_screen.dart',
      const [
        'pageCount = 8',
        "label: 'Сегодня'",
        "label: 'Люди'",
        "label: 'Расходы'",
        "label: 'Документы'",
        "label: 'Контроль'",
        "label: 'Закрытия'",
        "label: 'Выработка'",
        "label: 'Профиль'",
        'AdaptiveAccountingDashboardScreen(',
        'AdaptiveEmployeesScreen(',
        'ExpensesScreen()',
        'AccountingDocumentsScreen()',
        'AccountingControlScreen()',
        'EstimatorClosingInboxScreen(profile: widget.profile)',
        'EstimatorClosingOperationsIndexScreen(profile: widget.profile)',
        'onOpenPeople: () => select(1)',
        'onOpenExpenses: () => select(2)',
        'onOpenDocuments: () => select(3)',
        'onOpenControl: () => select(4)',
      ],
    );

    final main = source(
      'lib/features/accounting/presentation/accounting_main_screen.dart',
    );
    expect(main, isNot(contains("label: 'Операции'")));
    expect(main, isNot(contains("label: 'Отчёты'")));
    expect(main, isNot(contains('onOpenPayments')));
    expect(main, isNot(contains('onOpenReports')));
    expect(main, isNot(contains('AdaptiveAccountingOperationsScreen')));
    expect(main, isNot(contains('AdaptiveAccountingReportsScreen')));

    containsAll(
      'lib/screens/adaptive_employees_screen.dart',
      const [
        'widget.profile.isAccountant',
        "role: 'admin'",
        'DesktopEmployeesView(',
        'EmployeeDetailsScreen(profile: widget.profile',
        'PaymentsScreen(selectedObjectName:',
        'AbsenceFinesScreen()',
        'AddEmployeeScreen(',
      ],
    );

    containsAll(
      'lib/features/expenses/presentation/expenses_screen.dart',
      const ['ExpenseRepository'],
    );

    containsAll(
      'lib/features/accounting/presentation/accounting_documents_screen.dart',
      const [
        "('purchase', 'Поступления'",
        "('sale', 'Реализация'",
        "('counterparties', 'Контрагенты'",
        "('materials', 'Материалы'",
        'createDocument(',
        'createCounterparty(',
        'createMaterialWriteOff(',
        'AccountingDocumentDetailScreen(',
        'onTap: () => openDocument(row)',
      ],
    );

    containsAll(
      'lib/features/accounting/presentation/accounting_control_screen.dart',
      const [
        "('calendar', 'Календарь'",
        "('checks', 'Проверки'",
        "('osv', 'ОСВ'",
        "('reporting', 'Отчётность'",
        "title: 'Просрочено · ",
        "title: 'Ближайшие · ",
        "title: 'Выполнено · ",
        'AccountingTaskDetailScreen(',
        'AccountingDocumentDetailScreen(',
        'AccountingPaymentDetailScreen(row: match!)',
        'get_accounting_trial_balance',
        'accounting_journal_entries',
        'accounting_journal_lines',
      ],
    );
  });

  test('бухгалтерские детали поддерживают редактирование и deep-link', () {
    containsAll(
      'lib/features/accounting/presentation/adaptive_accounting_dashboard_screen.dart',
      const [
        'AccountingBankDetailsMode.accounts',
        'AccountingBankDetailsMode.incoming',
        'AccountingBankDetailsMode.outgoing',
        'AccountingTodayDetailsMode.balances',
        'AccountingTodayDetailsMode.missingReceipts',
        'AccountingTaskDetailScreen(',
        'AccountingDocumentDetailScreen(',
      ],
    );

    containsAll(
      'lib/features/accounting/presentation/accounting_bank_details_screen.dart',
      const [
        'AccountingBankTransactionDetailScreen',
        'AccountingBankAccountDetailScreen',
        'fetchBankTransactions',
        'fetchBankAccounts',
      ],
    );

    containsAll(
      'lib/features/accounting/presentation/accounting_document_detail_screen.dart',
      const [
        'Редактировать документ',
        'Добавить файл',
        'Заменить',
        'Удалить',
        'updateDocument(',
        'replaceDocumentFile(',
      ],
    );

    containsAll(
      'lib/features/accounting/presentation/accounting_task_detail_screen.dart',
      const [
        'Редактировать задачу',
        'Отметить выполненной',
        'Вернуть в работу',
        'updateCalendarTask(',
      ],
    );
  });

  test('новые бухгалтерские данные имеют отдельные репозитории', () {
    containsAll(
      'lib/features/accounting/data/accounting_workbench_repository.dart',
      const [
        "from('accounting_bank_transactions')",
        "from('accounting_primary_documents')",
        "from('accounting_counterparties')",
        "from('accounting_material_movements')",
        "from('accounting_calendar_tasks')",
        'createBankTransaction(',
        'createDocument(',
        'createCounterparty(',
        'createMaterialWriteOff(',
        'createCalendarTask(',
      ],
    );

    containsAll(
      'lib/features/accounting/data/accounting_detail_repository.dart',
      const [
        'fetchDocument(',
        'updateDocument(',
        'addDocumentFile(',
        'deleteDocumentFile(',
        'replaceDocumentFile(',
        'fetchCalendarTask(',
        'updateCalendarTask(',
      ],
    );
  });

  test('бухгалтер получает рабочие права раздела Люди без администрирования аккаунтов', () {
    const path =
        'supabase/migrations/20260908130000_expand_accountant_people_workspace_access.sql';
    containsAll(
      path,
      const [
        "('accountant', 'employees.create')",
        "('accountant', 'employees.edit')",
        "('accountant', 'employees.archive')",
        "('accountant', 'documents.workflow.view')",
        'employees_insert_company_accountant_workspace',
        'employees_update_company_accountant_workspace',
        'employee_private_data_select_company_accountant',
        'employee_private_data_update_company_accountant',
        'employee_comments_select_company_accountant',
        'employee_documents_select_company_accountant',
        "public.current_user_role() = 'accountant'",
        'can_access_absence_fine_storage',
        'get_pending_absence_fines',
        'confirm_absence_fine',
        'cancel_absence_fine',
      ],
    );

    final migration = source(path);
    expect(migration, isNot(contains("('accountant', 'employees.delete')")));
    expect(migration, isNot(contains('company_memberships')));
    expect(migration, isNot(contains('employee_access')));
  });
}
