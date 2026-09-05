import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('панели специалистов используют один крупный стеклянный каркас', () {
    final shared = source(
      'lib/features/shared/presentation/specialist_desktop_ui.dart',
    );

    expect(shared, contains('width: 56'));
    expect(shared, contains('height: 56'));
    expect(shared, contains('fontSize: 25'));
    expect(shared, contains('pressedScale: 0.975'));
    expect(shared, isNot(contains('child: Text(\n                    hint!')));
    expect(shared, isNot(contains('subtitle: subtitle')));
  });

  test('HR панель не показывает обучающие пояснения', () {
    final hr = source(
      'lib/features/recruitment/presentation/recruitment_dashboard_screen.dart',
    );

    expect(hr, contains('PremiumActionButton('));
    expect(hr, contains("label: 'Все заявки · \${data.total}'"));
    expect(hr, contains('RecruitmentRepository.fetchDashboard'));
    expect(hr, isNot(contains('Затем подключим Telegram-бота')));
    expect(hr, isNot(contains("child: const Text('Открыть все')")));
  });

  test('бухгалтерия использует единый рабочий экран операций без дубля навигации', () {
    final main = source(
      'lib/features/accounting/presentation/accounting_main_screen.dart',
    );
    final operations = source(
      'lib/features/accounting/presentation/adaptive_accounting_operations_screen.dart',
    );

    expect(main, contains('AdaptiveAccountingOperationsScreen'));
    expect(main, contains("label: 'Операции'"));
    expect(main, contains("label: 'Документы'"));
    expect(main, contains("label: 'Контроль'"));
    expect(operations, contains('Future<void> addBankTransaction()'));
    expect(operations, contains('Future<void> addExpense()'));
    expect(operations, contains("label: const Text('Добавить операцию')"));
    expect(operations, contains("label: const Text('Импорт выписки')"));
  });

  test('юрист использует чистые карточки без лишних кнопок открытия', () {
    final mobile = source(
      'lib/features/legal/presentation/legal_dashboard_screen.dart',
    );
    final desktop = source(
      'lib/features/legal/presentation/adaptive_legal_dashboard_screen.dart',
    );

    expect(mobile, contains('LegalRepository.fetchDashboard()'));
    expect(mobile, contains("label: 'Недельный отчёт'"));
    expect(mobile, isNot(contains('Документы, сроки, юридические вопросы')));
    expect(desktop, contains('widget.onOpenDocument(document)'));
    expect(desktop, contains('widget.onOpenMatter(matter)'));
    expect(desktop, isNot(contains("child: const Text('Все документы')")));
    expect(desktop, isNot(contains("child: const Text('Все вопросы')")));
  });

  test('панель разработчика остаётся функциональной и без пояснялок', () {
    final developer = source(
      'lib/features/developer/presentation/developer_system_screen.dart',
    );

    expect(developer, contains('DeveloperPanelScreen(profile: profile)'));
    expect(developer, contains('RolePermissionMatrixScreen()'));
    expect(developer, contains('CompanyManagementScreen('));
    expect(developer, contains('DeveloperReadinessScreen(profile: profile)'));
    expect(developer, contains('Widget actionGrid('));
    expect(developer, isNot(contains('required String subtitle')));
    expect(developer, isNot(contains('Конфигурация текущей компании')));
  });
}
