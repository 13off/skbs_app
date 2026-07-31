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

  test('бухгалтерия сохраняет выплаты без дублирующей навигации', () {
    final mobile = source(
      'lib/features/accounting/presentation/accounting_dashboard_screen.dart',
    );
    final desktop = source(
      'lib/features/accounting/presentation/adaptive_accounting_dashboard_screen.dart',
    );

    expect(mobile, contains('AddPaymentScreen('));
    expect(mobile, contains("label: 'Добавить выплату'"));
    expect(mobile, isNot(contains("label: 'Открыть отчёты'")));
    expect(mobile, isNot(contains('Проверьте подтверждающие файлы')));
    expect(desktop, contains('Future<void> addPayment()'));
    expect(desktop, contains("label: const Text('Добавить выплату')"));
    expect(desktop, isNot(contains("label: const Text('Отчёты')")));
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
