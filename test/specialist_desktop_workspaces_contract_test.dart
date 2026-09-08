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

  test('accountant platform uses shared people and expenses desktop workspaces', () {
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
    final people = source('lib/screens/adaptive_employees_screen.dart');
    final expenses = source(
      'lib/features/expenses/presentation/expenses_screen.dart',
    );
    final repository = source(
      'lib/features/accounting/data/accounting_repository.dart',
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
    expect(dashboard, contains('onTap: widget.onOpenPeople'));
    expect(dashboard, contains('onTap: widget.onOpenExpenses'));
    expect(dashboard, contains('onTap: widget.onOpenDocuments'));
    expect(dashboard, contains('onTap: widget.onOpenControl'));
    expect(dashboard, isNot(contains('onOpenPayments')));
    expect(dashboard, isNot(contains('onOpenReports')));
    expect(dashboard, isNot(contains('Открыть операции')));
    expect(dashboard, isNot(contains("label: const Text('Открыть расходы')")));
    expect(dashboard, isNot(contains("title: 'Крупные остатки сотрудникам'")));
    expect(dashboard, isNot(contains("label: const Text('Контроль')")));
    expect(dashboard, isNot(contains("label: const Text('Документы')")));

    expect(mobileDashboard, contains('AccountingTodayDetailsMode.balances'));
    expect(mobileDashboard, contains('AccountingTodayDetailsMode.payments'));
    expect(
      mobileDashboard,
      contains('AccountingTodayDetailsMode.missingReceipts'),
    );
    expect(mobileDashboard, contains('AccountingPaymentDetailScreen'));
    expect(mobileDashboard, contains('fetchSettlementPaymentRegister'));
    expect(mobileDashboard, isNot(contains('widget.onOpenPeople')));
    expect(mobileDashboard, isNot(contains('widget.onOpenExpenses')));
    expect(mobileDashboard, isNot(contains('Widget workspaceActions()')));
    expect(mobileDashboard, isNot(contains("label: const Text('Люди')")));
    expect(mobileDashboard, isNot(contains("label: const Text('Расходы')")));
    expect(mobileDashboard, isNot(contains("label: const Text('Документы')")));
    expect(mobileDashboard, isNot(contains("label: const Text('Контроль')")));
    expect(mobileDashboard, isNot(contains("'Крупные остатки'")));
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
