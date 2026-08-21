import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/data/app_cache_coordinator.dart';
import 'package:skbs_app/data/app_data_sync.dart';

void main() {
  group('AppCacheCoordinator', () {
    test('company change invalidates every coordinated cache', () {
      expect(
        AppCacheCoordinator.areasFor(const <AppDataDomain>{
          AppDataDomain.company,
        }),
        equals(AppCacheCoordinator.allAreas),
      );
    });

    test('object change keeps the established dependent cache contract', () {
      expect(
        AppCacheCoordinator.areasFor(const <AppDataDomain>{
          AppDataDomain.objects,
        }),
        equals(const <AppCacheArea>{
          AppCacheArea.objects,
          AppCacheArea.developerPolicies,
          AppCacheArea.employees,
          AppCacheArea.timesheetGroups,
          AppCacheArea.attendance,
          AppCacheArea.financeSummary,
          AppCacheArea.payments,
          AppCacheArea.tasks,
          AppCacheArea.managerReports,
          AppCacheArea.managerWeeklyContribution,
        }),
      );
    });

    test('unrelated procurement event does not clear working data caches', () {
      expect(
        AppCacheCoordinator.areasFor(const <AppDataDomain>{
          AppDataDomain.procurement,
        }),
        isEmpty,
      );
    });
  });

  group('AppDataSync optimization contract', () {
    final syncSource = File('lib/data/app_data_sync.dart').readAsStringSync();
    final cacheSource = File(
      'lib/data/app_cache_coordinator.dart',
    ).readAsStringSync();

    test('continuous event storms have a bounded delivery delay', () {
      expect(syncSource, contains('_maxCoalesceDuration'));
      expect(syncSource, contains('_maxDeliveryTimer ??= Timer'));
    });

    test(
      'obsolete realtime subscriptions cannot refresh the active company',
      () {
        expect(syncSource, contains('_subscriptionGeneration'));
        expect(syncSource, contains('_isCurrentSubscription'));
        expect(syncSource, contains('identical(channel, _channel)'));
      },
    );

    test('employee cabinet cache is cleared only once per batch', () {
      final clearCalls = RegExp(
        r'EmployeeTaskCabinetRepository\.clearCache\(\);',
      ).allMatches(cacheSource);
      expect(clearCalls.length, 1);
    });
  });
}
