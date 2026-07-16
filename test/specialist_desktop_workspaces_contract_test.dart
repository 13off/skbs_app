import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('lawyer platform uses adaptive desktop workspaces', () {
    final main = source(
      'lib/features/legal/presentation/legal_main_screen.dart',
    );
    final dashboard = source(
      'lib/features/legal/presentation/adaptive_legal_dashboard_screen.dart',
    );
    final documents = source(
      'lib/features/legal/presentation/adaptive_legal_documents_screen.dart',
    );
    final matters = source(
      'lib/features/legal/presentation/adaptive_legal_matters_screen.dart',
    );

    expect(main, contains('AdaptiveLegalDashboardScreen'));
    expect(main, contains('AdaptiveLegalDocumentsScreen'));
    expect(main, contains('AdaptiveLegalMattersScreen'));
    expect(main, contains('ProfessionalBottomNavigation'));
    expect(main, contains('selectTabNavigator'));
    expect(main, contains('LegalDocumentDetailsScreen'));
    expect(main, contains('LegalMatterDetailsScreen'));

    expect(dashboard, contains('specialistDesktopBreakpoint'));
    expect(dashboard, contains('LegalDashboardScreen(profile: profile)'));
    expect(dashboard, contains("title: 'Юридический контроль'"));
    expect(documents, contains('LegalDocumentsScreen('));
    expect(documents, contains('SpecialistDesktopTable'));
    expect(documents, contains("title: 'Юридические документы'"));
    expect(documents, isNot(contains('LegalDocumentStatus.active')));
    expect(matters, contains('LegalMattersScreen('));
    expect(matters, contains('SpecialistDesktopTable'));
    expect(matters, contains("title: managerMode ? 'Решения и риски'"));
  });

  test('accountant platform uses adaptive desktop workspaces', () {
    final main = source(
      'lib/features/accounting/presentation/accounting_main_screen.dart',
    );
    final dashboard = source(
      'lib/features/accounting/presentation/adaptive_accounting_dashboard_screen.dart',
    );
    final payments = source(
      'lib/features/accounting/presentation/adaptive_accounting_payments_screen.dart',
    );
    final reports = source(
      'lib/features/accounting/presentation/adaptive_accounting_reports_screen.dart',
    );
    final repository = source(
      'lib/features/accounting/data/accounting_repository.dart',
    );

    expect(main, contains('AdaptiveAccountingDashboardScreen'));
    expect(main, contains('AdaptiveAccountingPaymentsScreen'));
    expect(main, contains('AdaptiveAccountingReportsScreen'));
    expect(main, contains('ProfessionalBottomNavigation'));

    expect(dashboard, contains('AccountingDashboardScreen('));
    expect(dashboard, contains('specialistDesktopBreakpoint'));
    expect(dashboard, contains("title: 'Финансовый контроль'"));
    expect(payments, contains('return const PaymentsScreen();'));
    expect(payments, contains('SpecialistDesktopTable'));
    expect(payments, contains("title: 'Выплаты и остатки'"));
    expect(payments, contains("label: const Text('Детальный режим')"));
    expect(reports, contains('return const AccountingReportsScreen();'));
    expect(reports, contains('SpecialistDesktopTable'));
    expect(reports, contains("title: 'Финансовые отчёты'"));
    expect(reports, contains('allObjectsScopeValue'));
    expect(repository, contains('fetchBalanceRows'));
  });

  test('desktop specialist layout keeps web breakpoint and mobile fallbacks', () {
    final ui = source(
      'lib/features/shared/presentation/specialist_desktop_ui.dart',
    );
    final table = source(
      'lib/features/shared/presentation/specialist_desktop_table.dart',
    );

    expect(ui, contains('specialistDesktopBreakpoint = 1050'));
    expect(ui, contains('BoxConstraints(maxWidth: 1460)'));
    expect(ui, contains('PremiumWorkBackdrop'));
    expect(table, contains('SingleChildScrollView'));
    expect(table, contains('scrollDirection: Axis.horizontal'));
    expect(table, contains('.toDouble()'));
  });
}
