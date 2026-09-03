import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../features/timesheet/data/timesheet_group_repository.dart';
import '../models/app_user_profile.dart';
import 'app_state.dart';
import 'attendance_repository.dart';
import 'employee_repository.dart';
import 'finance_summary_repository.dart';
import 'object_repository.dart';
import 'task_repository.dart';

/// Warms the exact caches used by the first working screens while the UI thread
/// is idle. Preloading is best-effort: failures never block navigation.
class AppPreloadCoordinator {
  AppPreloadCoordinator._();

  static const Duration _warmTtl = Duration(seconds: 45);
  static final Map<String, DateTime> _lastWarm = <String, DateTime>{};
  static final Map<String, Future<void>> _inFlight = <String, Future<void>>{};
  static int _generation = 0;

  static void clear() {
    _generation++;
    _lastWarm.clear();
    _inFlight.clear();
  }

  static String? _cleanObject(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  static String _key(AppUserProfile profile, String? objectName) {
    final day = AttendanceRepository.dateKey(AppState.today);
    return '${profile.activeCompanyId}::${_cleanObject(objectName) ?? '__all__'}::$day';
  }

  static void schedule({
    required AppUserProfile profile,
    String? objectName,
    bool forceRefresh = false,
  }) {
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (generation != _generation) return;
      SchedulerBinding.instance.scheduleTask<void>(
        () {
          if (generation != _generation) return;
          unawaited(
            preload(
              profile: profile,
              objectName: objectName,
              forceRefresh: forceRefresh,
            ),
          );
        },
        Priority.idle,
        debugLabel: 'AppStroy.preload',
      );
    });
  }

  static Future<void> preload({
    required AppUserProfile profile,
    String? objectName,
    bool forceRefresh = false,
  }) {
    final cleanObject = _cleanObject(objectName);
    final key = _key(profile, cleanObject);
    final warmedAt = _lastWarm[key];
    if (!forceRefresh &&
        warmedAt != null &&
        DateTime.now().difference(warmedAt) < _warmTtl) {
      return Future<void>.value();
    }

    final running = _inFlight[key];
    if (running != null) return running;

    final generation = _generation;
    late final Future<void> request;
    request = _runPreload(objectName: cleanObject, forceRefresh: forceRefresh)
        .then((_) {
          if (generation == _generation) _lastWarm[key] = DateTime.now();
        })
        .catchError((Object _) {
          // Best effort only. The destination screen retains its normal loader.
        })
        .whenComplete(() {
          if (identical(_inFlight[key], request)) _inFlight.remove(key);
        });
    _inFlight[key] = request;
    return request;
  }

  static Future<void> _runPreload({
    required String? objectName,
    required bool forceRefresh,
  }) async {
    final today = AppState.today;
    final employeesFuture = EmployeeRepository.fetchEmployees(
      objectName: objectName,
      includeFired: true,
      forceRefresh: forceRefresh,
    );

    // First wave: data behind the tabs a master opens most often.
    await Future.wait<dynamic>(<Future<dynamic>>[
      employeesFuture,
      ObjectRepository.fetchObjects(forceRefresh: forceRefresh),
      AttendanceRepository.fetchShiftValuesForDate(
        today,
        objectName: objectName,
        forceRefresh: forceRefresh,
      ),
      TaskRepository.fetchTasksForDate(
        today,
        objectName: objectName,
        forceRefresh: forceRefresh,
      ),
      TimesheetGroupRepository.fetchGroups(
        objectName: objectName,
        forceRefresh: forceRefresh,
      ),
    ]).timeout(const Duration(seconds: 8));

    // Second wave: heavier current-month aggregates. They run only after the
    // first useful data is warm and are served from PostgreSQL aggregation RPCs.
    await Future.wait<dynamic>(<Future<dynamic>>[
      AttendanceRepository.fetchMonthlyTimesheet(
        year: today.year,
        month: today.month,
        objectName: objectName,
        includeFired: true,
        forceRefresh: forceRefresh,
      ),
      FinanceSummaryRepository.fetchSummary(
        period: FinancePeriod.current(today),
        objectName: objectName,
        forceRefresh: forceRefresh,
      ),
    ]).timeout(const Duration(seconds: 8));
  }
}
