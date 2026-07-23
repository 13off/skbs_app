import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260723170000_get_notification_feed_fast.sql';

  test('notification feed is loaded through one protected RPC', () {
    final source = File('lib/data/notification_repository.dart').readAsStringSync();
    final start = source.indexOf(
      'static Future<List<AppNotification>> fetchLatest',
    );
    final end = source.indexOf('static Future<bool> hasUnread', start);

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final fetchLatest = source.substring(start, end);
    expect(fetchLatest, contains("'get_notification_feed_fast'"));
    expect(fetchLatest, contains("'p_object_name'"));
    expect(fetchLatest, contains("'p_limit'"));
    expect(fetchLatest, contains("map['is_read'] == true"));
    expect(fetchLatest, isNot(contains('fetchCurrentProfile')));
    expect(fetchLatest, isNot(contains(".from('app_notifications')")));
    expect(fetchLatest, isNot(contains('_fetchClearDate')));
    expect(fetchLatest, isNot(contains('_fetchReadNotificationIds')));
  });

  test('server RPC preserves scope, clearing and read state', () {
    final sql = File(migrationPath).readAsStringSync();

    expect(sql, contains('security invoker'));
    expect(sql, contains('with ctx as materialized'));
    expect(sql, contains('user_profiles'));
    expect(sql, contains("ctx.user_role = 'foreman'"));
    expect(sql, contains('profile_object'));
    expect(sql, contains('app_notification_clears'));
    expect(sql, contains("clear_row.object_name = ''"));
    expect(sql, contains('app_notification_reads'));
    expect(sql, contains('as is_read'));
    expect(sql, contains("'operational_overdue_tasks'"));
    expect(sql, contains("'operational_missing_photos'"));
    expect(sql, contains("'operational_timesheet_missing'"));
    expect(sql, contains("'ai_draft'"));
    expect(sql, contains('least(greatest(coalesce(p_limit, 40), 1), 100)'));
  });

  test('notification feed RPC is not exposed to anonymous users', () {
    final sql = File(migrationPath).readAsStringSync();

    expect(sql, contains('from public, anon'));
    expect(sql, contains('to authenticated'));
    expect(sql, isNot(contains('security definer')));
  });
}
