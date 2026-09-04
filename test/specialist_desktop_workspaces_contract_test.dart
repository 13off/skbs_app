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

  test('accountant platform uses merged adaptive desktop workspace', () {
    final main = source(
      'lib/features/accounting/presentation/accounting_main_screen.dart',
    );
    final dashboard = source(
      'lib/features/accounting/presentation/adaptive_accounting_dashboard_screen.dart',
    );
    final payments = source(
      'lib/features/accounting/presentation/adaptive_accounting_payments_screen.dart',
    );
    final repository = source(
      'lib/features/accounting/data/accounting_repository.dart',
    );

    expect(main, contains('AdaptiveAccountingDashboardScreen'));
    expect(main, contains('AdaptiveAccountingPaymentsScreen'));
    expect(main, isNot(contains('AdaptiveAccountingReportsScreen')));
    expect(main, contains('ProfessionalBottomNavigation'));
    expect(main, contains('onOpenReports: () => select(1)'));

    expect(dashboard, contains('AccountingDashboardScreen('));
    expect(dashboard, contains('specialistDesktopBreakpoint'));
    expect(dashboard, contains("title: 'Финансовый контроль'"));
    expect(payments, contains('return const PaymentsScreen();'));
    expect(payments, contains('SpecialistDesktopTable'));
    expect(payments, contains("title: 'Выплаты и расчёты'"));
    expect(payments, contains('PaymentReportExporter.download('));
    expect(payments, contains("label: const Text('Скачать XLSX')"));
    expect(payments, contains('PeriodTimesheetScreen('));
    expect(repository, contains('fetchBalanceRows'));
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
