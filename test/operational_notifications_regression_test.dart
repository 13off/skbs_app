import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('operational notification engine is scheduled and deduplicated', () {
    final engine = source(
      'supabase/migrations/20260722230000_operational_notifications_engine.sql',
    );
    final schedule = source(
      'supabase/migrations/20260722230100_schedule_operational_notifications.sql',
    );

    expect(engine, contains('app_notifications_operational_dedupe_idx'));
    expect(engine, contains('refresh_operational_notifications'));
    expect(engine, contains('create_ai_draft_ready_notification'));
    expect(engine, contains('on conflict do nothing'));
    expect(engine, contains("current_user_has_permission('notifications.center.view')"));
    expect(engine, contains("current_user_has_permission('ai.use')"));
    expect(schedule, contains('private.refresh_all_operational_notifications()'));
    expect(schedule, contains("'15 * * * *'"));
  });

  test('notification event groups keep old HR contract and new signals', () {
    final compatibility = source(
      'supabase/migrations/20260722230200_operational_notification_event_group_compatibility.sql',
    );

    expect(compatibility, contains("then 'hr'"));
    expect(compatibility, isNot(contains("then 'recruitment'")));
    expect(compatibility, contains('operational_overdue_tasks'));
    expect(compatibility, contains('operational_timesheet_missing'));
    expect(compatibility, contains('operational_payment_debt'));
    expect(compatibility, contains('operational_document_deadline'));
  });

  test('client refreshes on demand and loads the protected fast feed', () {
    final notifications = source('lib/data/notification_repository.dart');
    final feed = source(
      'supabase/migrations/20260723170000_get_notification_feed_fast.sql',
    );
    final refreshCall = notifications.indexOf(
      'await _refreshOperationalNotifications();',
    );
    final feedRpc = notifications.indexOf(
      "'get_notification_feed_fast'",
      refreshCall,
    );

    expect(notifications, contains('_refreshOperationalNotifications'));
    expect(notifications, contains("rpc<void>('refresh_operational_notifications')"));
    expect(refreshCall, greaterThanOrEqualTo(0));
    expect(feedRpc, greaterThan(refreshCall));
    expect(notifications, contains("'p_object_name'"));
    expect(notifications, contains("'p_limit'"));
    expect(feed, contains("ctx.user_role = 'foreman'"));
    expect(feed, contains("'operational_overdue_tasks'"));
    expect(feed, contains("'operational_missing_photos'"));
    expect(feed, contains("'operational_timesheet_missing'"));
    expect(feed, contains("'ai_draft'"));
  });

  test('AI action draft creates personal ready notification', () {
    final assistant = source(
      'lib/features/ai/data/ai_assistant_repository.dart',
    );

    expect(assistant, contains('create_ai_draft_ready_notification'));
    expect(assistant, contains("'p_action_type': action.type"));
    expect(assistant, contains("'p_action_id': action.id"));
    expect(assistant, contains('return result;'));
  });
}
