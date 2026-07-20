import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/data/app_cache_coordinator.dart';
import 'package:skbs_app/data/app_data_sync.dart';

void main() {
  test('сотрудники очищают зависимые операционные кеши', () {
    final areas = AppCacheCoordinator.areasFor(
      const <AppDataDomain>{AppDataDomain.employees},
    );

    expect(
      areas,
      const <AppCacheArea>{
        AppCacheArea.employees,
        AppCacheArea.attendance,
        AppCacheArea.financeSummary,
        AppCacheArea.managerReports,
      },
    );
  });

  test('выплаты очищают финансы, табель и отчёты', () {
    final areas = AppCacheCoordinator.areasFor(
      const <AppDataDomain>{AppDataDomain.payments},
    );

    expect(
      areas,
      const <AppCacheArea>{
        AppCacheArea.payments,
        AppCacheArea.attendance,
        AppCacheArea.financeSummary,
        AppCacheArea.managerReports,
      },
    );
  });

  test('задачи не сбрасывают несвязанные справочники', () {
    final areas = AppCacheCoordinator.areasFor(
      const <AppDataDomain>{AppDataDomain.tasks},
    );

    expect(
      areas,
      const <AppCacheArea>{
        AppCacheArea.tasks,
        AppCacheArea.managerReports,
      },
    );
  });

  test('изменение объектов очищает все зависимые данные объекта', () {
    final areas = AppCacheCoordinator.areasFor(
      const <AppDataDomain>{AppDataDomain.objects},
    );

    expect(
      areas,
      const <AppCacheArea>{
        AppCacheArea.objects,
        AppCacheArea.developerPolicies,
        AppCacheArea.employees,
        AppCacheArea.attendance,
        AppCacheArea.financeSummary,
        AppCacheArea.payments,
        AppCacheArea.tasks,
        AppCacheArea.managerReports,
      },
    );
  });

  test('служебные направления очищают только центр отчётов', () {
    for (final domain in const <AppDataDomain>[
      AppDataDomain.notifications,
      AppDataDomain.legal,
      AppDataDomain.recruitment,
    ]) {
      expect(
        AppCacheCoordinator.areasFor(<AppDataDomain>{domain}),
        const <AppCacheArea>{AppCacheArea.managerReports},
      );
    }
  });

  test('смена компании очищает весь пользовательский кеш', () {
    expect(
      AppCacheCoordinator.areasFor(
        const <AppDataDomain>{AppDataDomain.company},
      ),
      AppCacheCoordinator.allAreas,
    );
  });

  test('оболочки используют единую точку очистки кешей', () {
    final mainScreen = File('lib/screens/main_screen.dart').readAsStringSync();
    final managerShell = File(
      'lib/features/reports/presentation/manager_main_screen.dart',
    ).readAsStringSync();
    final premiumShell = File(
      'lib/features/shell/presentation/premium_main_screen.dart',
    ).readAsStringSync();

    expect(mainScreen, contains('AppCacheCoordinator.clearAll()'));
    expect(managerShell, contains('AppCacheCoordinator.invalidate'));
    expect(premiumShell, contains('AppCacheCoordinator.invalidate'));
    expect(managerShell, isNot(contains('void invalidateCaches(')));
    expect(premiumShell, isNot(contains('void invalidateDataCaches(')));
    expect(mainScreen, isNot(contains('void clearRepositoryCaches(')));
  });
}
