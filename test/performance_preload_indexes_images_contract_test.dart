import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main shell schedules idle cache preloading', () {
    final preload = File(
      'lib/data/app_preload_coordinator.dart',
    ).readAsStringSync();
    final shell = File(
      'lib/features/shell/presentation/premium_main_screen.dart',
    ).readAsStringSync();
    expect(preload, contains('Priority.idle'));
    expect(preload, contains('fetchMonthlyTimesheet'));
    expect(preload, contains('FinanceSummaryRepository.fetchSummary'));
    expect(shell, contains('AppPreloadCoordinator.schedule'));
  });

  test('heavy timesheet and payment totals are aggregated on PostgreSQL', () {
    final attendance = File(
      'lib/data/attendance_repository.dart',
    ).readAsStringSync();
    final payments = File(
      'lib/data/payment_repository.dart',
    ).readAsStringSync();
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
    final repository = File(
      'lib/data/task_photo_repository.dart',
    ).readAsStringSync();
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
    expect(
      rollback,
      contains('drop function if exists public.get_period_timesheet_fast'),
    );
  });
}
