import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('task forced refresh reuses a running request', () {
    final source = File('lib/data/task_repository.dart').readAsStringSync();
    final start = source.indexOf(
      'static Future<List<TaskItemData>> fetchTasksForDate',
    );
    final end = source.indexOf(
      'static Future<List<TaskItemData>> _fetchTasksForDate',
      start,
    );
    final method = source.substring(start, end);

    expect(method, contains('final running = _taskRequests[cacheKey];'));
    expect(method, contains('if (running != null)'));
    expect(method, isNot(contains('if (!forceRefresh) {')));
    expect(method, contains('forceRefresh: forceRefresh'));
  });

  test('unread forced refresh reuses a running request', () {
    final source = File(
      'lib/data/notification_repository.dart',
    ).readAsStringSync();
    final start = source.indexOf('static Future<bool> hasUnread');
    final end = source.indexOf('static Future<bool> _loadHasUnread', start);
    final method = source.substring(start, end);

    expect(method, contains('final pending = _unreadInFlight[key];'));
    expect(method, contains('if (pending != null) return pending;'));
    expect(method, isNot(contains('if (!forceRefresh) {')));
  });

  test('completed caches are still bypassed by force refresh', () {
    final tasks = File('lib/data/task_repository.dart').readAsStringSync();
    final notifications = File(
      'lib/data/notification_repository.dart',
    ).readAsStringSync();

    expect(tasks, contains('if (!forceRefresh && cached != null'));
    expect(notifications, contains('if (!forceRefresh &&'));
    expect(notifications, contains('now.difference(cached.loadedAt)'));
  });

  test('request maps are still cleaned only for the same future', () {
    final tasks = File('lib/data/task_repository.dart').readAsStringSync();
    final notifications = File(
      'lib/data/notification_repository.dart',
    ).readAsStringSync();

    expect(tasks, contains('identical(_taskRequests[cacheKey], request)'));
    expect(notifications, contains('identical(_unreadInFlight[key], future)'));
  });
}
