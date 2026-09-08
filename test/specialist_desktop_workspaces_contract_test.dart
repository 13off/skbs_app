import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('lawyer platform uses completed adaptive workspaces', () {
    final main = source(
      'lib/features/legal/presentation/legal_main_screen.dart',
    );
    final today = source(
      'lib/features/legal/presentation/legal_today_complete_screen.dart',
    );
    final base = source(
      'lib/features/legal/presentation/legal_base_complete_screen.dart',
    );
    final documents = source(
      'lib/features/legal/presentation/legal_documents_complete_screen.dart',
    );
    final matters = source(
      'lib/features/legal/presentation/legal_matters_complete_screen.dart',
    );

    expect(main, contains('LegalTodayCompleteScreen'));
    expect(main, contains('LegalBaseCompleteScreen'));
    expect(main, contains('LegalDocumentsCompleteScreen'));
    expect(main, contains('LegalMattersCompleteScreen'));
    expect(main, contains('PersistentTabShell'));
    expect(main, contains('ProfessionalBottomNavigationItem'));

    expect(today, contains("title: 'Сегодня'"));
    expect(today, contains('LegalOperationsRepository.fetchTodayItems'));
    expect(today, contains('Контроль базы'));
    expect(base, contains("title: 'База юриста'"));
    expect(base, contains('LegalEmployeeCompleteScreen'));
    expect(base, contains('LegalObjectCompleteScreen'));
    expect(base, contains('LegalCounterpartyCompleteScreen'));
    expect(documents, contains("title: 'Документы'"));
    expect(documents, contains('LegalDocumentCompleteScreen'));
    expect(documents, contains('Только требующие внимания'));
    expect(matters, contains("title: 'Дела'"));
    expect(matters, contains('LegalMatterCompleteScreen'));
    expect(matters, contains("('court', 'Суды')"));
    expect(matters, contains("('claim', 'Претензии')"));
  });

  test('accountant platform keeps contextual drilldowns across workspaces', () {
    final main = source(
      'lib/features/accounting/presentation/accounting_main_screen.dart',
    );
    final dashboard = source(
      'lib/features/accounting/presentation/adaptive_accounting_dashboard_screen.dart',
    );
    final mobileDashboard = source(
      'lib/features/accounting/presentation/accounting_dashboard_screen.dart',
    );
    final todayDetails = source(
      'lib/features/accounting/presentation/accounting_today_details_screen.dart',
    );
    final bankDetails = source(
      'lib/features/accounting/presentation/accounting_bank_details_screen.dart',
    );
    final documentDetails = source(
      'lib/features/accounting/presentation/accounting_document_detail_screen.dart',
    );
    final taskDetails = source(
      'lib/features/accounting/presentation/accounting_task_detail_screen.dart',
    );
    final documents = source(
      'lib/features/accounting/presentation/accounting_documents_screen.dart',
    );
    final control = source(
      'lib/features/accounting/presentation/accounting_control_screen.dart',
    );
    final people = source('lib/screens/adaptive_employees_screen.dart');
    final expenses = source(
      'lib/features/expenses/presentation/expenses_screen.dart',
    );
    final repository = source(
      'lib/features/accounting/data/accounting_repository.dart',
    );
    final detailRepository = source(
      'lib/features/accounting/data/accounting_detail_repository.dart',
    );

    expect(main, contains('AdaptiveAccountingDashboardScreen'));
    expect(main, contains('AdaptiveEmployeesScreen'));
    expect(main, contains('ExpensesScreen'));
    expect(main, contains('AccountingDocumentsScreen'));
    expect(main, contains('AccountingControlScreen'));
    expect(main, contains('PersistentTabShell'));
    expect(main, contains('onOpenPeople: () => select(1)'));
    expect(main, contains('onOpenExpenses: () => select(2)'));
    expect(main, contains('onOpenDocuments: () => select(3)'));
    expect(main, contains('onOpenControl: () => select(4)'));
    expect(main, isNot(contains('AdaptiveAccountingOperationsScreen')));

    expect(dashboard, contains('AccountingDashboardScreen('));
    expect(dashboard, contains('specialistDesktopBreakpoint'));
    expect(dashboard, contains("title: 'Сегодня'"));
    expect(dashboard, contains('AccountingBankDetailsScreen('));
    expect(dashboard, contains('AccountingBankDetailsMode.accounts'));
    expect(dashboard, contains('AccountingBankDetailsMode.incoming'));
    expect(dashboard, contains('AccountingBankDetailsMode.outgoing'));
    expect(dashboard, contains('AccountingTodayDetailsMode.balances'));
    expect(dashboard, contains('AccountingTodayDetailsMode.missingReceipts'));
    expect(dashboard, contains('AccountingDocumentDetailScreen('));
    expect(dashboard, contains('AccountingTaskDetailScreen('));
    expect(dashboard, isNot(contains('onTap: widget.onOpenPeople')));
    expect(dashboard, isNot(contains('onTap: widget.onOpenExpenses')));
    expect(dashboard, isNot(contains('onTap: widget.onOpenDocuments')));
    expect(dashboard, isNot(contains('onTap: widget.onOpenControl')));

    expect(mobileDashboard, contains('AccountingTodayDetailsMode.balances'));
    expect(mobileDashboard, contains('AccountingTodayDetailsMode.payments'));
    expect(
      mobileDashboard,
      contains('AccountingTodayDetailsMode.missingReceipts'),
    );
    expect(mobileDashboard, contains('AccountingPaymentDetailScreen'));
    expect(mobileDashboard, contains('fetchSettlementPaymentRegister'));
    expect(mobileDashboard, isNot(contains('Widget workspaceActions()')));
    expect(mobileDashboard, isNot(contains('AddPaymentScreen')));
    expect(mobileDashboard, isNot(contains('Добавить выплату')));

    expect(todayDetails, contains('AccountingEmployeeSettlementScreen'));
    expect(todayDetails, contains('AccountingPaymentDetailScreen'));
    expect(todayDetails, contains('AddPaymentScreen('));
    expect(todayDetails, contains('PaymentHistoryScreen('));
    expect(todayDetails, contains('PaymentReceiptRepository.pickReceiptFiles'));
    expect(todayDetails, contains('PaymentRepository.addReceiptsToPayment'));
    expect(todayDetails, contains('Осталось выплатить'));
    expect(todayDetails, contains('Приложить чек к этой выплате'));

    expect(bankDetails, contains('AccountingBankTransactionDetailScreen'));
    expect(bankDetails, contains('AccountingBankAccountDetailScreen'));
    expect(bankDetails, contains('fetchBankTransactions'));
    expect(bankDetails, contains('fetchBankAccounts'));

    expect(documents, contains('AccountingDocumentDetailScreen('));
    expect(documents, contains('onTap: () => openDocument(row)'));
    expect(documentDetails, contains('Редактировать документ'));
    expect(documentDetails, contains('Добавить файл'));
    expect(documentDetails, contains('replaceDocumentFile'));
    expect(documentDetails, contains('deleteDocumentFile'));

    expect(control, contains('AccountingTaskDetailScreen('));
    expect(control, contains('AccountingDocumentDetailScreen('));
    expect(control, contains('AccountingPaymentDetailScreen(row: match!)'));
    expect(control, contains('onTap: () => openTask(task)'));
    expect(control, contains('onTap: () => openDocument(row)'));
    expect(taskDetails, contains('Редактировать задачу'));
    expect(taskDetails, contains('Отметить выполненной'));
    expect(taskDetails, contains('Вернуть в работу'));

    expect(detailRepository, contains('fetchDocument('));
    expect(detailRepository, contains('updateDocument('));
    expect(detailRepository, contains('replaceDocumentFile('));
    expect(detailRepository, contains('fetchCalendarTask('));
    expect(detailRepository, contains('updateCalendarTask('));

    expect(people, contains('desktopBreakpoint = 1050'));
    expect(people, contains('kIsWeb && constraints.maxWidth >= desktopBreakpoint'));
    expect(people, contains('DesktopEmployeesView('));
    expect(people, contains('PaymentsScreen('));

    expect(expenses, contains('_desktopListWidth = 1120'));
    expect(expenses, contains('Widget expenseListHeader()'));
    expect(expenses, contains('Widget desktopExpenseCard('));
    expect(repository, contains('fetchBalanceRows'));
    expect(repository, contains('fetchSettlementPaymentRegister'));
    expect(repository, contains('employee: employee'));
  });

  test(
    'desktop specialist layout keeps web breakpoint and mobile fallbacks',
    () {
      final ui = source(
        'lib/features/shared/presentation/specialist_desktop_ui.dart',
      );
      final table = source(
        'lib/features/shared/presentation/specialist_desktop_table.dart',
      );

      expect(
        ui,
        contains(
          'specialistDesktopBreakpoint = AppUi.specialistDesktopBreakpoint',
        ),
      );
      expect(ui, contains('maxContentWidth: AppUi.specialistContentWidth'));
      expect(ui, contains('return AppPage('));
      expect(table, contains('SingleChildScrollView'));
      expect(table, contains('scrollDirection: Axis.horizontal'));
      expect(table, contains('.toDouble()'));
    },
  );
}
