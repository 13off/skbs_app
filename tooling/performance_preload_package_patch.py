from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / 'lib'


def replace_once(path: Path, old: str, new: str):
    text = path.read_text(encoding='utf-8')
    if old not in text:
        raise RuntimeError(f'Pattern not found in {path}: {old[:100]!r}')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


# ---------------------------------------------------------------------------
# 1. Central idle preloader. It warms existing repository caches, never blocks UI.
# ---------------------------------------------------------------------------
preload = LIB / 'data/app_preload_coordinator.dart'
preload.write_text(r'''import 'dart:async';

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
    request = _runPreload(
      objectName: cleanObject,
      forceRefresh: forceRefresh,
    ).then((_) {
      if (generation == _generation) _lastWarm[key] = DateTime.now();
    }).catchError((Object _) {
      // Best effort only. The destination screen retains its normal loader.
    }).whenComplete(() {
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
''', encoding='utf-8')

# Hook preloader into the main shell and object switching.
shell = LIB / 'features/shell/presentation/premium_main_screen.dart'
text = shell.read_text(encoding='utf-8')
for old_import in [
    "import '../../../data/app_state.dart';\n",
    "import '../../../data/attendance_repository.dart';\n",
    "import '../../../data/employee_repository.dart';\n",
    "import '../../../data/object_repository.dart';\n",
]:
    text = text.replace(old_import, '')
if "import '../../../data/app_preload_coordinator.dart';\n" not in text:
    text = text.replace(
        "import '../../../data/app_data_sync.dart';\n",
        "import '../../../data/app_data_sync.dart';\nimport '../../../data/app_preload_coordinator.dart';\n",
        1,
    )
text = text.replace(
    '''    setActiveAppBackHandler(handleBackRequest);\n    startDataSync();\n  }''',
    '''    setActiveAppBackHandler(handleBackRequest);\n    startDataSync();\n    AppPreloadCoordinator.schedule(\n      profile: widget.profile,\n      objectName: selectedObjectNameNotifier.value,\n    );\n  }''',
    1,
)
text = text.replace(
    '''    if (oldWidget.profile.activeCompanyId != widget.profile.activeCompanyId) {\n      AppDataSync.stop(companyId: oldWidget.profile.activeCompanyId);\n      startDataSync();\n    }''',
    '''    if (oldWidget.profile.activeCompanyId != widget.profile.activeCompanyId) {\n      AppDataSync.stop(companyId: oldWidget.profile.activeCompanyId);\n      AppPreloadCoordinator.clear();\n      startDataSync();\n      AppPreloadCoordinator.schedule(\n        profile: widget.profile,\n        objectName: selectedObjectNameNotifier.value,\n        forceRefresh: true,\n      );\n    }''',
    1,
)
old_warm = '''  Future<void> warmUpVisibleData() async {\n    final token = ++warmUpToken;\n\n    await Future<void>.delayed(const Duration(milliseconds: 80));\n\n    if (!mounted || token != warmUpToken) return;\n\n    final objectName = selectedObjectNameNotifier.value;\n    final today = AppState.today;\n\n    try {\n      await Future.wait<dynamic>([\n        EmployeeRepository.fetchEmployees(\n          objectName: objectName,\n          includeFired: true,\n        ),\n        AttendanceRepository.fetchShiftValuesForDate(\n          today,\n          objectName: objectName,\n        ),\n        TaskRepository.fetchTasksForDate(today, objectName: objectName),\n        ObjectRepository.fetchObjects(),\n      ]).timeout(const Duration(seconds: 7));\n    } catch (_) {\n      // Фоновый прогрев не должен мешать работе приложения.\n    }\n  }'''
new_warm = '''  Future<void> warmUpVisibleData() async {\n    final token = ++warmUpToken;\n    await AppPreloadCoordinator.preload(\n      profile: widget.profile,\n      objectName: selectedObjectNameNotifier.value,\n    );\n    if (!mounted || token != warmUpToken) return;\n  }'''
if old_warm not in text:
    raise RuntimeError('premium shell warmUpVisibleData pattern not found')
text = text.replace(old_warm, new_warm, 1)
shell.write_text(text, encoding='utf-8')

# ---------------------------------------------------------------------------
# 2. Finance summary gets a tiny cache so idle preloading is actually reusable.
# ---------------------------------------------------------------------------
finance = LIB / 'data/finance_summary_repository.dart'
text = finance.read_text(encoding='utf-8')
text = text.replace(
    '''  static final Map<String, Future<FinanceSummaryData>> _inFlight = {};\n\n  static void clearCache() {\n    _inFlight.clear();\n  }''',
    '''  static const Duration _cacheTtl = Duration(seconds: 20);\n  static final Map<String, Future<FinanceSummaryData>> _inFlight = {};\n  static final Map<String, _FinanceSummaryCacheEntry> _cache = {};\n  static int _cacheGeneration = 0;\n\n  static void clearCache() {\n    _cacheGeneration++;\n    _inFlight.clear();\n    _cache.clear();\n  }''',
    1,
)
old_fetch = '''  static Future<FinanceSummaryData> fetchSummary({\n    required FinancePeriod period,\n    String? objectName,\n    bool forceRefresh = false,\n  }) {\n    final key = _requestKey(period: period, objectName: objectName);\n\n    final running = _inFlight[key];\n\n    if (running != null) return running;\n\n    final future = _loadSummary(period: period, objectName: objectName);\n    _inFlight[key] = future;\n\n    future.whenComplete(() {\n      if (identical(_inFlight[key], future)) {\n        _inFlight.remove(key);\n      }\n    });\n\n    return future;\n  }'''
new_fetch = '''  static Future<FinanceSummaryData> fetchSummary({\n    required FinancePeriod period,\n    String? objectName,\n    bool forceRefresh = false,\n  }) {\n    final key = _requestKey(period: period, objectName: objectName);\n    final cached = _cache[key];\n    if (!forceRefresh &&\n        cached != null &&\n        DateTime.now().difference(cached.createdAt) < _cacheTtl) {\n      return Future<FinanceSummaryData>.value(cached.data);\n    }\n\n    final running = _inFlight[key];\n    if (running != null) return running;\n\n    final generation = _cacheGeneration;\n    late final Future<FinanceSummaryData> future;\n    future = _loadSummary(period: period, objectName: objectName).then((data) {\n      if (generation == _cacheGeneration) {\n        _cache[key] = _FinanceSummaryCacheEntry(\n          data: data,\n          createdAt: DateTime.now(),\n        );\n      }\n      return data;\n    }).whenComplete(() {\n      if (identical(_inFlight[key], future)) _inFlight.remove(key);\n    });\n    _inFlight[key] = future;\n    return future;\n  }'''
if old_fetch not in text:
    raise RuntimeError('finance fetch pattern not found')
text = text.replace(old_fetch, new_fetch, 1)
text += '''\n\nclass _FinanceSummaryCacheEntry {\n  final FinanceSummaryData data;\n  final DateTime createdAt;\n\n  const _FinanceSummaryCacheEntry({required this.data, required this.createdAt});\n}\n'''
finance.write_text(text, encoding='utf-8')

# ---------------------------------------------------------------------------
# 3. Move monthly/period aggregation from Dart loops to PostgreSQL RPCs.
# ---------------------------------------------------------------------------
attendance = LIB / 'data/attendance_repository.dart'
text = attendance.read_text(encoding='utf-8')
monthly_start = text.index('  static Future<List<MonthlyTimesheetRow>> _fetchMonthlyTimesheet({')
monthly_end = text.index('  static Future<MonthlyTimesheetRow> fetchMonthlyTimesheetForEmployee({', monthly_start)
monthly_method = r'''  static Future<List<MonthlyTimesheetRow>> _fetchMonthlyTimesheet({
    required int year,
    required int month,
    String? objectName,
    bool includeFired = false,
    bool forceRefresh = false,
  }) async {
    final generation = _cacheGeneration;
    final cleanObject = cleanObjectName(objectName);
    final cacheKey = _monthCacheKey(
      year: year,
      month: month,
      objectName: cleanObject,
      includeFired: includeFired,
    );
    final cached = _monthlyTimesheetCache[cacheKey];

    if (!forceRefresh &&
        cached != null &&
        _isFresh(cached.createdAt, _reportCacheTtl)) {
      return _copyMonthlyRows(cached.rows);
    }

    final response = await _client.rpc<dynamic>(
      'get_monthly_timesheet_fast',
      params: <String, dynamic>{
        'p_year': year,
        'p_month': month,
        'p_object_name': cleanObject,
        'p_include_fired': includeFired,
      },
    );
    if (response is! List) return <MonthlyTimesheetRow>[];

    final result = response.whereType<Map>().map<MonthlyTimesheetRow>((raw) {
      final row = Map<String, dynamic>.from(raw);
      final rawDays = row['shifts_by_day'];
      final shiftsByDay = <int, double>{};
      if (rawDays is Map) {
        for (final entry in rawDays.entries) {
          final day = int.tryParse(entry.key.toString());
          if (day != null) shiftsByDay[day] = _toDouble(entry.value);
        }
      }
      return MonthlyTimesheetRow(
        employee: Employee.fromSupabase(row),
        shiftsByDay: shiftsByDay,
        paid: _toDouble(row['paid']),
      );
    }).toList(growable: false);

    if (generation == _cacheGeneration) {
      _monthlyTimesheetCache[cacheKey] = _MonthlyTimesheetCacheEntry(
        rows: _copyMonthlyRows(result),
        createdAt: DateTime.now(),
      );
    }
    return _copyMonthlyRows(result);
  }

'''
text = text[:monthly_start] + monthly_method + text[monthly_end:]
period_start = text.index('  static Future<List<PeriodTimesheetRow>> _fetchPeriodTimesheet({')
period_end = text.index('\n}\n\nclass _AttendanceTotals', period_start)
period_method = r'''  static Future<List<PeriodTimesheetRow>> _fetchPeriodTimesheet({
    required DateTime startDate,
    required DateTime endDate,
    String? objectName,
    bool includeFired = false,
    bool forceRefresh = false,
  }) async {
    final generation = _cacheGeneration;
    final cleanObject = cleanObjectName(objectName);
    final cacheKey = _periodCacheKey(
      startDate: startDate,
      endDate: endDate,
      objectName: cleanObject,
      includeFired: includeFired,
    );
    final cached = _periodTimesheetCache[cacheKey];

    if (!forceRefresh &&
        cached != null &&
        _isFresh(cached.createdAt, _reportCacheTtl)) {
      return _copyPeriodRows(cached.rows);
    }

    final response = await _client.rpc<dynamic>(
      'get_period_timesheet_fast',
      params: <String, dynamic>{
        'p_start_date': dateKey(startDate),
        'p_end_date': dateKey(endDate),
        'p_object_name': cleanObject,
        'p_include_fired': includeFired,
      },
    );
    if (response is! List) return <PeriodTimesheetRow>[];

    final result = response.whereType<Map>().map<PeriodTimesheetRow>((raw) {
      final row = Map<String, dynamic>.from(raw);
      final rawDates = row['shifts_by_date'];
      final shiftsByDate = <String, double>{};
      if (rawDates is Map) {
        for (final entry in rawDates.entries) {
          shiftsByDate[entry.key.toString()] = _toDouble(entry.value);
        }
      }
      return PeriodTimesheetRow(
        employee: Employee.fromSupabase(row),
        shiftsByDate: shiftsByDate,
      );
    }).toList(growable: false);

    if (generation == _cacheGeneration) {
      _periodTimesheetCache[cacheKey] = _PeriodTimesheetCacheEntry(
        rows: _copyPeriodRows(result),
        createdAt: DateTime.now(),
      );
    }
    return _copyPeriodRows(result);
  }
'''
text = text[:period_start] + period_method + text[period_end:]
attendance.write_text(text, encoding='utf-8')

# ---------------------------------------------------------------------------
# 4. Payment overview fetches only SUM(amount), not every payment + receipt.
# ---------------------------------------------------------------------------
payment = LIB / 'data/payment_repository.dart'
text = payment.read_text(encoding='utf-8')
text = text.replace(
    '''  static const Duration _bulkPaymentsCacheTtl = Duration(seconds: 20);\n''',
    '''  static const Duration _bulkPaymentsCacheTtl = Duration(seconds: 20);\n  static const Duration _paymentTotalsCacheTtl = Duration(seconds: 20);\n''',
    1,
)
text = text.replace(
    '''  static final Map<String, Future<List<PaymentRecord>>> _bulkPaymentRequests =\n      {};\n  static int _cacheGeneration = 0;''',
    '''  static final Map<String, Future<List<PaymentRecord>>> _bulkPaymentRequests =\n      {};\n  static final Map<String, _PaymentTotalsCacheEntry> _paymentTotalsCache = {};\n  static final Map<String, Future<Map<String, double>>> _paymentTotalsRequests = {};\n  static int _cacheGeneration = 0;''',
    1,
)
text = text.replace(
    '''    _employeePaymentRequests.clear();\n    _bulkPaymentRequests.clear();\n  }''',
    '''    _employeePaymentRequests.clear();\n    _bulkPaymentRequests.clear();\n    _paymentTotalsCache.clear();\n    _paymentTotalsRequests.clear();\n  }''',
    1,
)
text = text.replace(
    '''    _employeePaymentRequests.remove(cleanEmployeeId);\n    _bulkPaymentRequests.clear();\n  }''',
    '''    _employeePaymentRequests.remove(cleanEmployeeId);\n    _bulkPaymentRequests.clear();\n    _paymentTotalsCache.clear();\n    _paymentTotalsRequests.clear();\n  }''',
    1,
)
insert_at = text.index('  static Future<List<PaymentReceipt>> addReceiptsToPayment({')
payment_totals_methods = r'''  static String _paymentTotalsKey({
    required List<String> employeeIds,
    required int periodYear,
    required int periodMonth,
    required DateTime startDate,
    required DateTime endDate,
    required bool byPaymentDate,
  }) {
    return '${employeeIds.join('|')}::$periodYear::$periodMonth::'
        '${dateKey(startDate)}::${dateKey(endDate)}::$byPaymentDate';
  }

  static Future<Map<String, double>> fetchPaymentTotalsForEmployees(
    List<String> employeeIds, {
    required int periodYear,
    required int periodMonth,
    required DateTime startDate,
    required DateTime endDate,
    required bool byPaymentDate,
    bool forceRefresh = false,
  }) async {
    final cleanIds = employeeIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    if (cleanIds.isEmpty) return <String, double>{};

    final key = _paymentTotalsKey(
      employeeIds: cleanIds,
      periodYear: periodYear,
      periodMonth: periodMonth,
      startDate: startDate,
      endDate: endDate,
      byPaymentDate: byPaymentDate,
    );
    final cached = _paymentTotalsCache[key];
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.createdAt) < _paymentTotalsCacheTtl) {
      return Map<String, double>.from(cached.totals);
    }

    final running = _paymentTotalsRequests[key];
    if (running != null) return Map<String, double>.from(await running);

    final generation = _cacheGeneration;
    late final Future<Map<String, double>> request;
    request = _loadPaymentTotals(
      employeeIds: cleanIds,
      periodYear: periodYear,
      periodMonth: periodMonth,
      startDate: startDate,
      endDate: endDate,
      byPaymentDate: byPaymentDate,
    ).then((totals) {
      if (generation == _cacheGeneration) {
        _paymentTotalsCache[key] = _PaymentTotalsCacheEntry(
          totals: Map<String, double>.from(totals),
          createdAt: DateTime.now(),
        );
      }
      return totals;
    }).whenComplete(() {
      if (identical(_paymentTotalsRequests[key], request)) {
        _paymentTotalsRequests.remove(key);
      }
    });
    _paymentTotalsRequests[key] = request;
    return Map<String, double>.from(await request);
  }

  static Future<Map<String, double>> _loadPaymentTotals({
    required List<String> employeeIds,
    required int periodYear,
    required int periodMonth,
    required DateTime startDate,
    required DateTime endDate,
    required bool byPaymentDate,
  }) async {
    final response = await _client.rpc<dynamic>(
      'get_payment_totals_fast',
      params: <String, dynamic>{
        'p_employee_ids': employeeIds,
        'p_period_year': periodYear,
        'p_period_month': periodMonth,
        'p_start_date': dateKey(startDate),
        'p_end_date': dateKey(endDate),
        'p_by_payment_date': byPaymentDate,
      },
    );
    if (response is! List) return <String, double>{};
    final totals = <String, double>{};
    for (final raw in response.whereType<Map>()) {
      final row = Map<String, dynamic>.from(raw);
      final employeeId = row['employee_id']?.toString().trim() ?? '';
      if (employeeId.isEmpty) continue;
      totals[employeeId] = _toDouble(row['paid']);
    }
    return totals;
  }

'''
text = text[:insert_at] + payment_totals_methods + text[insert_at:]
text += '''\n\nclass _PaymentTotalsCacheEntry {\n  final Map<String, double> totals;\n  final DateTime createdAt;\n\n  const _PaymentTotalsCacheEntry({required this.totals, required this.createdAt});\n}\n'''
payment.write_text(text, encoding='utf-8')

payments_screen = LIB / 'features/payments/presentation/screens/payments_screen.dart'
text = payments_screen.read_text(encoding='utf-8')
old_payment_loop = '''      final paymentRows = await PaymentRepository.fetchPaymentsForEmployees(\n        employeeIds,\n        forceRefresh: forceRefresh,\n      );\n      final paidByEmployeeId = <String, double>{};\n      final cleanStart = DateTime(\n        startDate.year,\n        startDate.month,\n        startDate.day,\n      );\n      final cleanEnd = DateTime(endDate.year, endDate.month, endDate.day);\n      for (final payment in paymentRows) {\n        final matches = mode == _PaymentAccountingMode.settlementPeriod\n            ? payment.periodYear == targetMonth.year &&\n                  payment.periodMonth == targetMonth.month\n            : () {\n                final date = DateTime(\n                  payment.paymentDate.year,\n                  payment.paymentDate.month,\n                  payment.paymentDate.day,\n                );\n                return !date.isBefore(cleanStart) && !date.isAfter(cleanEnd);\n              }();\n        if (!matches) continue;\n        paidByEmployeeId[payment.employeeId] =\n            (paidByEmployeeId[payment.employeeId] ?? 0) + payment.amount;\n      }'''
new_payment_loop = '''      final cleanStart = DateTime(\n        startDate.year,\n        startDate.month,\n        startDate.day,\n      );\n      final cleanEnd = DateTime(endDate.year, endDate.month, endDate.day);\n      final paidByEmployeeId =\n          await PaymentRepository.fetchPaymentTotalsForEmployees(\n            employeeIds,\n            periodYear: targetMonth.year,\n            periodMonth: targetMonth.month,\n            startDate: cleanStart,\n            endDate: cleanEnd,\n            byPaymentDate: mode == _PaymentAccountingMode.paymentDate,\n            forceRefresh: forceRefresh,\n          );'''
if old_payment_loop not in text:
    raise RuntimeError('payments screen payment loop not found')
text = text.replace(old_payment_loop, new_payment_loop, 1)
payments_screen.write_text(text, encoding='utf-8')

# ---------------------------------------------------------------------------
# 5. PWA task-photo thumbnails: upload a derived 420px file and use it in grid.
# ---------------------------------------------------------------------------
photo_repo = LIB / 'data/task_photo_repository.dart'
text = photo_repo.read_text(encoding='utf-8')
text = text.replace(
    "'id, task_id, storage_path, original_name, photo_stage, created_at',",
    "'id, task_id, storage_path, thumbnail_path, original_name, photo_stage, created_at',",
)
# safe thumbnail path after safeStoragePath
anchor = '''  static String safeStoragePath({\n    required String taskId,\n    required String photoStage,\n    required TaskPhotoFile photo,\n    required int index,\n    DateTime? now,\n  }) {\n    final timestamp = (now ?? DateTime.now()).millisecondsSinceEpoch;\n    final extension = photo.extension.isEmpty ? 'jpg' : photo.extension;\n    return '$taskId/$photoStage/${timestamp}_$index.$extension';\n  }\n'''
addition = anchor + '''\n  static String safeThumbnailStoragePath({\n    required String taskId,\n    required String photoStage,\n    required int index,\n    required int timestamp,\n    String extension = 'jpg',\n  }) {\n    final cleanExtension = extension.trim().isEmpty ? 'jpg' : extension.trim();\n    return '$taskId/$photoStage/thumbs/${timestamp}_$index.$cleanExtension';\n  }\n'''
if anchor not in text:
    raise RuntimeError('photo safe path anchor not found')
text = text.replace(anchor, addition, 1)
old_items = '''    final uploadItems = List.generate(photos.length, (index) {\n      final photo = photos[index];\n      return (\n        photo: photo,\n        path: safeStoragePath(\n          taskId: taskId,\n          photoStage: photoStage,\n          photo: photo,\n          index: index + 1,\n        ),\n      );\n    });\n    final uploadedPaths = <String>[];\n    final loadedBytesByPath = <String, int>{\n      for (final item in uploadItems) item.path: 0,\n    };\n    final totalBytes = photos.fold<int>(\n      0,\n      (sum, photo) => sum + photo.bytes.length,\n    );'''
new_items = '''    final uploadItems = List.generate(photos.length, (index) {\n      final photo = photos[index];\n      final timestamp = DateTime.now().millisecondsSinceEpoch + index;\n      final path = safeStoragePath(\n        taskId: taskId,\n        photoStage: photoStage,\n        photo: photo,\n        index: index + 1,\n        now: DateTime.fromMillisecondsSinceEpoch(timestamp),\n      );\n      final thumbnailPath = photo.hasThumbnail\n          ? safeThumbnailStoragePath(\n              taskId: taskId,\n              photoStage: photoStage,\n              index: index + 1,\n              timestamp: timestamp,\n              extension: photo.thumbnailExtension,\n            )\n          : null;\n      return (photo: photo, path: path, thumbnailPath: thumbnailPath);\n    });\n    final uploadedPaths = <String>[];\n    final loadedBytesByPath = <String, int>{\n      for (final item in uploadItems) item.path: 0,\n      for (final item in uploadItems)\n        if (item.thumbnailPath != null) item.thumbnailPath!: 0,\n    };\n    final totalBytes = photos.fold<int>(\n      0,\n      (sum, photo) =>\n          sum + photo.bytes.length + (photo.thumbnailBytes?.length ?? 0),\n    );'''
if old_items not in text:
    raise RuntimeError('photo upload items pattern not found')
text = text.replace(old_items, new_items, 1)
old_worker_tail = '''          loadedBytesByPath[item.path] = item.photo.bytes.length;\n          uploadedPaths.add(item.path);\n          completedFiles += 1;\n          emitProgress();'''
new_worker_tail = '''          loadedBytesByPath[item.path] = item.photo.bytes.length;\n          uploadedPaths.add(item.path);\n\n          final thumbnailPath = item.thumbnailPath;\n          final thumbnailBytes = item.photo.thumbnailBytes;\n          if (thumbnailPath != null &&\n              thumbnailBytes != null &&\n              thumbnailBytes.isNotEmpty) {\n            final thumbnailPhoto = TaskPhotoFile(\n              originalName: item.photo.originalName,\n              contentType: item.photo.thumbnailContentType,\n              extension: item.photo.thumbnailExtension,\n              bytes: thumbnailBytes,\n            );\n            await _uploadPhotoBytes(\n              path: thumbnailPath,\n              photo: thumbnailPhoto,\n              onProgress: (loadedBytes) {\n                loadedBytesByPath[thumbnailPath] =\n                    loadedBytes.clamp(0, thumbnailBytes.length).toInt();\n                emitProgress();\n              },\n            );\n            loadedBytesByPath[thumbnailPath] = thumbnailBytes.length;\n            uploadedPaths.add(thumbnailPath);\n          }\n\n          completedFiles += 1;\n          emitProgress();'''
if old_worker_tail not in text:
    raise RuntimeError('photo worker tail pattern not found')
text = text.replace(old_worker_tail, new_worker_tail, 1)
old_rows = '''      final rowsToInsert = uploadItems\n          .map(\n            (item) => <String, String>{\n              'task_id': taskId,\n              'storage_path': item.path,\n              'original_name': item.photo.originalName,\n              'photo_stage': photoStage,\n            },\n          )\n          .toList();'''
new_rows = '''      final rowsToInsert = uploadItems\n          .map(\n            (item) => <String, dynamic>{\n              'task_id': taskId,\n              'storage_path': item.path,\n              'thumbnail_path': item.thumbnailPath,\n              'original_name': item.photo.originalName,\n              'photo_stage': photoStage,\n            },\n          )\n          .toList();'''
if old_rows not in text:
    raise RuntimeError('photo rows insert pattern not found')
text = text.replace(old_rows, new_rows, 1)
text = text.replace(
    '''    await removeStoragePaths(<String>[photo.storagePath]);''',
    '''    await removeStoragePaths(<String>[\n      photo.storagePath,\n      if (photo.thumbnailPath.trim().isNotEmpty) photo.thumbnailPath,\n    ]);''',
    1,
)
old_signed = '''  static Future<String> createSignedUrl(TaskPhotoData photo) {\n    return _client.storage\n        .from(bucketName)\n        .createSignedUrl(photo.storagePath, signedUrlLifetimeSeconds);\n  }'''
new_signed = '''  static Future<String> createSignedUrl(TaskPhotoData photo) {\n    return createSignedUrlForPath(photo.storagePath);\n  }\n\n  static Future<String> createSignedUrlForPath(String storagePath) {\n    return _client.storage\n        .from(bucketName)\n        .createSignedUrl(storagePath, signedUrlLifetimeSeconds);\n  }'''
if old_signed not in text:
    raise RuntimeError('photo signed URL pattern not found')
text = text.replace(old_signed, new_signed, 1)
photo_repo.write_text(text, encoding='utf-8')

# Signed URL cache separates preview and original paths.
cache = LIB / 'data/task_photo_signed_url_cache.dart'
cache.write_text(r'''import 'task_photo_models.dart';
import 'task_photo_repository.dart';

class TaskPhotoSignedUrlCache {
  static const Duration cacheTtl = Duration(minutes: 8);

  static final Map<String, _TaskPhotoSignedUrlEntry> _entries =
      <String, _TaskPhotoSignedUrlEntry>{};
  static final Map<String, Future<String>> _requests = <String, Future<String>>{};

  const TaskPhotoSignedUrlCache._();

  static String _originalKey(TaskPhotoData photo) => photo.storagePath.trim();
  static String _previewKey(TaskPhotoData photo) => photo.previewStoragePath.trim();

  static String? _cachedPath(String key) {
    if (key.isEmpty) return null;
    final entry = _entries[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.createdAt) >= cacheTtl) {
      _entries.remove(key);
      return null;
    }
    return entry.url;
  }

  static String? cachedUrl(TaskPhotoData photo) => _cachedPath(_originalKey(photo));

  static String? cachedPreviewUrl(TaskPhotoData photo) =>
      _cachedPath(_previewKey(photo));

  static Future<String> getSignedUrl(TaskPhotoData photo) {
    return _getSignedUrlForPath(_originalKey(photo));
  }

  static Future<String> getPreviewSignedUrl(TaskPhotoData photo) {
    return _getSignedUrlForPath(_previewKey(photo));
  }

  static Future<String> _getSignedUrlForPath(String key) {
    final cached = _cachedPath(key);
    if (cached != null) return Future<String>.value(cached);
    if (key.isEmpty) {
      return Future<String>.error(ArgumentError.value(key, 'storagePath'));
    }

    final running = _requests[key];
    if (running != null) return running;

    late final Future<String> request;
    request = TaskPhotoRepository.createSignedUrlForPath(key).then((url) {
      _entries[key] = _TaskPhotoSignedUrlEntry(
        url: url,
        createdAt: DateTime.now(),
      );
      return url;
    }).whenComplete(() {
      if (identical(_requests[key], request)) _requests.remove(key);
    });
    _requests[key] = request;
    return request;
  }

  static Future<void> prewarmPreviews(Iterable<TaskPhotoData> photos) async {
    await Future.wait<void>(
      photos.map((photo) async {
        try {
          await getPreviewSignedUrl(photo);
        } catch (_) {
          // Preview warmup is best-effort.
        }
      }),
    );
  }

  static void evict(TaskPhotoData photo) {
    for (final key in <String>{_originalKey(photo), _previewKey(photo)}) {
      if (key.isEmpty) continue;
      _entries.remove(key);
      _requests.remove(key);
    }
  }

  static void clear() {
    _entries.clear();
    _requests.clear();
  }
}

class _TaskPhotoSignedUrlEntry {
  final String url;
  final DateTime createdAt;

  const _TaskPhotoSignedUrlEntry({required this.url, required this.createdAt});
}
''', encoding='utf-8')

editor = LIB / 'screens/task_details/task_details_editor_screen.dart'
text = editor.read_text(encoding='utf-8')
if "import 'dart:async';\n" not in text:
    text = "import 'dart:async';\n\n" + text
editor.write_text(text, encoding='utf-8')

loading = LIB / 'screens/task_details/task_details_loading.dart'
text = loading.read_text(encoding='utf-8')
text = text.replace(
    '''  Future<String> signedUrlFuture(TaskPhotoData photo) {\n    return signedUrlFutures.putIfAbsent(\n      photo.id,\n      () => TaskPhotoSignedUrlCache.getSignedUrl(photo),\n    );\n  }''',
    '''  Future<String> previewSignedUrlFuture(TaskPhotoData photo) {\n    return signedUrlFutures.putIfAbsent(\n      'preview:${photo.id}',\n      () => TaskPhotoSignedUrlCache.getPreviewSignedUrl(photo),\n    );\n  }''',
    1,
)
text = text.replace(
    '''        signedUrlFutures.clear();\n        isLoading = false;''',
    '''        signedUrlFutures.clear();\n        isLoading = false;''',
    1,
)
# After state update, prewarm first visible thumbnails without blocking the screen.
needle = '''      });\n    } catch (error) {\n'''
replacement = '''      });\n      unawaited(TaskPhotoSignedUrlCache.prewarmPreviews(loadedPhotos.take(6)));\n    } catch (error) {\n'''
if needle not in text:
    raise RuntimeError('task loading post-state anchor not found')
text = text.replace(needle, replacement, 1)
loading.write_text(text, encoding='utf-8')

sections = LIB / 'screens/task_details/task_details_sections.dart'
text = sections.read_text(encoding='utf-8')
text = text.replace(
    'final cachedUrl = TaskPhotoSignedUrlCache.cachedUrl(photo);',
    'final cachedUrl = TaskPhotoSignedUrlCache.cachedPreviewUrl(photo);',
    1,
)
text = text.replace('future: signedUrlFuture(photo),', 'future: previewSignedUrlFuture(photo),', 1)
text = text.replace(
    '''        gaplessPlayback: true,\n        filterQuality: FilterQuality.medium,''',
    '''        gaplessPlayback: true,\n        cacheWidth: 512,\n        cacheHeight: 512,\n        filterQuality: FilterQuality.low,''',
    1,
)
sections.write_text(text, encoding='utf-8')

# ---------------------------------------------------------------------------
# 6. Regression contract for the whole isolated package.
# ---------------------------------------------------------------------------
test = ROOT / 'test/performance_preload_indexes_images_contract_test.dart'
test.write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main shell schedules idle cache preloading', () {
    final preload = File('lib/data/app_preload_coordinator.dart').readAsStringSync();
    final shell = File(
      'lib/features/shell/presentation/premium_main_screen.dart',
    ).readAsStringSync();
    expect(preload, contains('Priority.idle'));
    expect(preload, contains('fetchMonthlyTimesheet'));
    expect(preload, contains('FinanceSummaryRepository.fetchSummary'));
    expect(shell, contains('AppPreloadCoordinator.schedule'));
  });

  test('heavy timesheet and payment totals are aggregated on PostgreSQL', () {
    final attendance = File('lib/data/attendance_repository.dart').readAsStringSync();
    final payments = File('lib/data/payment_repository.dart').readAsStringSync();
    final screen = File(
      'lib/features/payments/presentation/screens/payments_screen.dart',
    ).readAsStringSync();
    expect(attendance, contains("'get_monthly_timesheet_fast'"));
    expect(attendance, contains("'get_period_timesheet_fast'"));
    expect(payments, contains("'get_payment_totals_fast'"));
    expect(screen, contains('fetchPaymentTotalsForEmployees'));
  });

  test('task grid uses derived thumbnails while viewer keeps original', () {
    final model = File('lib/data/task_photo_models.dart').readAsStringSync();
    final repository = File('lib/data/task_photo_repository.dart').readAsStringSync();
    final sections = File(
      'lib/screens/task_details/task_details_sections.dart',
    ).readAsStringSync();
    final viewer = File(
      'lib/screens/task_details/task_details_photo_viewer.dart',
    ).readAsStringSync();
    expect(model, contains('previewStoragePath'));
    expect(repository, contains("'thumbnail_path'"));
    expect(sections, contains('cachedPreviewUrl'));
    expect(sections, contains('cacheWidth: 512'));
    expect(viewer, contains('TaskPhotoSignedUrlCache.getSignedUrl(photo)'));
  });

  test('migration contains reversible hot-path indexes and aggregate RPCs', () {
    final migration = File(
      'supabase/migrations/20260821123000_performance_preload_indexes_reports_images.sql',
    ).readAsStringSync();
    final rollback = File(
      'supabase/rollback/20260821123000_performance_preload_indexes_reports_images_rollback.sql',
    ).readAsStringSync();
    expect(migration, contains('employees_hot_scope_fio_idx'));
    expect(migration, contains('payments_hot_employee_date_idx'));
    expect(migration, contains('get_period_timesheet_fast'));
    expect(migration, contains('thumbnail_path'));
    expect(rollback, contains('drop function if exists public.get_period_timesheet_fast'));
  });
}
''', encoding='utf-8')

print('Performance preload/index/report/image package applied')
